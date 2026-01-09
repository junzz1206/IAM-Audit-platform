import React, { useState, useEffect } from 'react';
import { 
  Typography, Box, Table, TableBody, TableCell, TableContainer, 
  TableHead, TableRow, Paper, Chip, Grid, TextField, Button, InputAdornment, CircularProgress, Tooltip, Stack,
  FormControl, Select, MenuItem, InputLabel // 🌟 드롭다운용 컴포넌트 추가
} from '@mui/material';
import CreditCardIcon from '@mui/icons-material/CreditCard';
import SearchIcon from '@mui/icons-material/Search';
import RefreshIcon from '@mui/icons-material/Refresh';
import FilterListIcon from '@mui/icons-material/FilterList'; 
import SortIcon from '@mui/icons-material/Sort'; // 🌟 정렬 아이콘

// 아이콘들
import FormatListBulletedIcon from '@mui/icons-material/FormatListBulleted'; 
import CheckCircleIcon from '@mui/icons-material/CheckCircle'; 
import ErrorIcon from '@mui/icons-material/Error'; 
import BoltIcon from '@mui/icons-material/Bolt'; 
import NewReleasesIcon from '@mui/icons-material/NewReleases'; 

import { coreApi } from '../api/axios'; 

function Violation() {
  const [rows, setRows] = useState([]); 
  const [filteredRows, setFilteredRows] = useState([]); 
  const [loading, setLoading] = useState(true);

  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [keyword, setKeyword] = useState('');
  const [filterType, setFilterType] = useState('ALL');
  
  // 🌟 [추가] 정렬 상태 (기본값: UPLOAD - 업로드 순)
  const [sortOrder, setSortOrder] = useState('UPLOAD');

  const getSeverity = (amount, reason = '') => {
    if (reason.includes('유흥') || reason.includes('쪼개기') || amount >= 500000) {
        return { label: 'DANGER', color: 'error' }; 
    }
    if (reason.includes('한도') || reason.includes('주말') || reason.includes('심야')) {
        return { label: 'WARNING', color: 'warning' }; 
    }
    return { label: 'CHECK', color: 'info' }; 
  };

  const fetchViolations = async () => {
    try {
      setLoading(true);
      const response = await coreApi.get('/violations'); 
      setRows(response.data);
      // 데이터 가져오면 현재 설정된 필터/정렬 적용
      applyFilters(response.data, filterType, startDate, endDate, keyword, sortOrder);
    } catch (error) {
      console.error("데이터 로딩 실패:", error);
      setRows([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchViolations();
  }, []);

  // 🌟 [수정] 상태가 바뀔 때마다 필터링 + 정렬 실행
  useEffect(() => {
    applyFilters(rows, filterType, startDate, endDate, keyword, sortOrder);
  }, [rows, filterType, startDate, endDate, keyword, sortOrder]);

  const applyFilters = (data, type, start, end, key, sort) => {
    // 1. 필터링 먼저 수행
    let result = data.filter((row) => {
      const rowDate = row.tx_date ? row.tx_date.split(' ')[0] : '';
      const isAfterStart = start ? rowDate >= start : true;
      const isBeforeEnd = end ? rowDate <= end : true;
      const query = key.toLowerCase();
      const matchesKeyword = 
        (row.user_name && row.user_name.toLowerCase().includes(query)) || 
        (row.department && row.department.toLowerCase().includes(query)) ||
        (row.merchant && row.merchant.toLowerCase().includes(query));

      if (!isAfterStart || !isBeforeEnd || !matchesKeyword) return false;

      if (type === 'ALL') return true; 
      if (type === 'PASS') return row.status === 'PASS'; 
      if (type === 'FAIL') return row.status === 'FAIL'; 

      const severity = getSeverity(row.amount, row.reason);
      if (type === 'DANGER') return row.status === 'FAIL' && severity.label === 'DANGER';
      if (type === 'WARNING') return row.status === 'FAIL' && severity.label === 'WARNING';

      return true;
    });

    // 🌟 2. 정렬 로직 적용
    if (sort !== 'UPLOAD') {
        result.sort((a, b) => {
            // 날짜 문자열을 Date 객체로 변환하여 비교
            const dateA = new Date(a.tx_date.replace(" AM", "").replace(" PM", ""));
            const dateB = new Date(b.tx_date.replace(" AM", "").replace(" PM", ""));
            
            if (sort === 'NEWEST') {
                return dateB - dateA; // 내림차순 (최신순)
            } else {
                return dateA - dateB; // 오름차순 (과거순)
            }
        });
    }

    setFilteredRows(result);
  };

  const handleReset = () => {
    setStartDate('');
    setEndDate('');
    setKeyword('');
    setFilterType('ALL'); 
    setSortOrder('UPLOAD'); // 정렬도 초기화
  };

  return (
    <Box>
      <Typography variant="h4" gutterBottom fontWeight="bold" color="text.primary" sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
        <CreditCardIcon fontSize="large" sx={{ color: 'black' }} /> 
        법인카드 거래 내역 관리
      </Typography>
      <Typography mb={3} color="textSecondary">
        업로드된 모든 거래 내역을 조회하고, <strong>규정 위반(Violation)</strong> 건을 필터링하여 관리합니다.
      </Typography>

      {/* 검색 필터 */}
      <Paper sx={{ p: 3, mb: 4, bgcolor: '#fff', borderRadius: 2 }} elevation={1}>
        <Grid container spacing={2} alignItems="center">
          <Grid item xs={12} md={3}>
            <Box display="flex" gap={1} alignItems="center">
              <TextField type="date" size="small" fullWidth value={startDate} onChange={(e) => setStartDate(e.target.value)} label="시작일" InputLabelProps={{ shrink: true }} />
              <Typography>~</Typography>
              <TextField type="date" size="small" fullWidth value={endDate} onChange={(e) => setEndDate(e.target.value)} label="종료일" InputLabelProps={{ shrink: true }} />
            </Box>
          </Grid>
          <Grid item xs={12} md={3}>
            <TextField fullWidth size="small" placeholder="이름, 부서, 가맹점 검색" value={keyword} onChange={(e) => setKeyword(e.target.value)} InputProps={{ startAdornment: (<InputAdornment position="start"><SearchIcon color="action" /></InputAdornment>) }} />
          </Grid>
          
          {/* 🌟 [추가] 정렬 선택 박스 (작게) */}
          <Grid item xs={12} md={2}>
            <FormControl fullWidth size="small">
              <InputLabel id="sort-label">정렬 기준</InputLabel>
              <Select
                labelId="sort-label"
                value={sortOrder}
                label="정렬 기준"
                onChange={(e) => setSortOrder(e.target.value)}
                startAdornment={<SortIcon sx={{ mr: 1, color: 'action.active' }} />}
              >
                <MenuItem value="UPLOAD">업로드 순</MenuItem>
                <MenuItem value="NEWEST">최신순</MenuItem>
                <MenuItem value="OLDEST">과거순</MenuItem>
              </Select>
            </FormControl>
          </Grid>

          <Grid item xs={12} md={4} display="flex" justifyContent="flex-end">
            <Button variant="outlined" color="inherit" onClick={handleReset} startIcon={<RefreshIcon />}>검색 초기화</Button>
          </Grid>

          <Grid item xs={12}>
            <Box display="flex" alignItems="center" gap={1} mt={1} p={1} bgcolor="#f5f5f5" borderRadius={1}>
              <FilterListIcon color="action" />
              <Typography variant="body2" fontWeight="bold" mr={2}>보기 필터:</Typography>
              
              <Stack direction="row" spacing={1}>
                <Chip 
                    icon={<FormatListBulletedIcon style={{ color: '#1976d2' }} />} 
                    label="전체 보기" onClick={() => setFilterType('ALL')} 
                    variant={filterType === 'ALL' ? 'filled' : 'outlined'}
                    sx={{ borderColor: '#1976d2', color: filterType === 'ALL' ? '#fff' : '#1976d2', bgcolor: filterType === 'ALL' ? '#1976d2' : 'transparent', fontWeight: 'bold' }} clickable 
                />
                <Chip 
                    icon={<CheckCircleIcon style={{ color: '#2e7d32' }} />} 
                    label="정상 거래" onClick={() => setFilterType('PASS')} 
                    variant={filterType === 'PASS' ? 'filled' : 'outlined'}
                    sx={{ borderColor: '#2e7d32', color: filterType === 'PASS' ? '#fff' : '#2e7d32', bgcolor: filterType === 'PASS' ? '#2e7d32' : 'transparent', fontWeight: 'bold' }} clickable 
                />
                <Chip 
                    icon={<ErrorIcon style={{ color: '#d32f2f' }} />} 
                    label="위반 전체" onClick={() => setFilterType('FAIL')} 
                    variant={filterType === 'FAIL' ? 'filled' : 'outlined'}
                    sx={{ borderColor: '#d32f2f', color: filterType === 'FAIL' ? '#fff' : '#d32f2f', bgcolor: filterType === 'FAIL' ? '#d32f2f' : 'transparent', fontWeight: 'bold' }} clickable 
                />
                <Chip 
                    icon={<BoltIcon style={{ color: '#9c27b0' }} />} 
                    label="심각" onClick={() => setFilterType('DANGER')} 
                    variant={filterType === 'DANGER' ? 'filled' : 'outlined'}
                    sx={{ borderColor: '#9c27b0', color: filterType === 'DANGER' ? '#fff' : '#9c27b0', bgcolor: filterType === 'DANGER' ? '#9c27b0' : 'transparent', fontWeight: 'bold' }} clickable 
                />
                <Chip 
                    icon={<NewReleasesIcon style={{ color: '#ed6c02' }} />} 
                    label="주의" onClick={() => setFilterType('WARNING')} 
                    variant={filterType === 'WARNING' ? 'filled' : 'outlined'}
                    sx={{ borderColor: '#ed6c02', color: filterType === 'WARNING' ? '#fff' : '#ed6c02', bgcolor: filterType === 'WARNING' ? '#ed6c02' : 'transparent', fontWeight: 'bold' }} clickable 
                />
              </Stack>
            </Box>
          </Grid>
        </Grid> 
      </Paper>

      <TableContainer component={Paper} elevation={3} sx={{ borderRadius: 2, overflow: 'hidden' }}>
        <Table sx={{ minWidth: 650 }}>
          <TableHead sx={{ bgcolor: '#ffffff', borderBottom: '2px solid #e0e0e0' }}>
            <TableRow>
              <TableCell sx={{ fontWeight: 'bold' }}>일시</TableCell>
              <TableCell sx={{ fontWeight: 'bold' }}>사용자 (부서)</TableCell>
              <TableCell sx={{ fontWeight: 'bold' }}>카드 정보</TableCell>
              <TableCell sx={{ fontWeight: 'bold' }}>가맹점</TableCell>
              <TableCell sx={{ fontWeight: 'bold' }}>금액</TableCell>
              <TableCell sx={{ fontWeight: 'bold' }}>상태 / 사유</TableCell>
              <TableCell sx={{ fontWeight: 'bold', textAlign: 'center' }}>판정</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {loading ? (
               <TableRow><TableCell colSpan={7} align="center" sx={{ py: 5 }}><CircularProgress /></TableCell></TableRow>
            ) : filteredRows.length > 0 ? (
              filteredRows.map((row, index) => {
                const severity = getSeverity(row.amount, row.reason || '');
                const isFail = row.status === 'FAIL';
                const rowBgColor = isFail ? '#fff5f5' : '#e8f5e9';

                return (
                  <TableRow key={index} hover sx={{ bgcolor: rowBgColor }}>
                    <TableCell>{row.tx_date}</TableCell>
                    <TableCell>
                      <Typography variant="body2" fontWeight="bold">{row.user_name}</Typography>
                      <Typography variant="caption" color="textSecondary">{row.department}</Typography>
                    </TableCell>
                    <TableCell>
                      <Tooltip title={row.card_id || ''}>
                        <Box display="flex" alignItems="center" gap={0.5} sx={{ color: '#555' }}>
                          <CreditCardIcon fontSize="small" />
                          <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>
                            ****-{row.card_id ? row.card_id.slice(-4) : '0000'}
                          </Typography>
                        </Box>
                      </Tooltip>
                    </TableCell>
                    <TableCell>{row.merchant}</TableCell>
                    <TableCell sx={{ fontWeight: 'bold', color: 'inherit' }}>
                       ₩{Number(row.amount).toLocaleString()}
                    </TableCell>
                    <TableCell>
                        {isFail ? (
                            <Typography variant="body2" color="error" fontWeight="medium">{row.reason}</Typography>
                        ) : (
                            <Typography variant="body2" color="success.main" fontWeight="bold">정상 승인</Typography>
                        )}
                    </TableCell>
                    <TableCell align="center">
                      {isFail ? (
                          <Chip 
                            label={severity.label} 
                            color={severity.color} 
                            size="small" 
                            sx={{ fontWeight: 'bold', minWidth: 80 }}
                          />
                      ) : (
                          <Chip label="PASS" color="success" size="small" variant="filled" />
                      )}
                    </TableCell>
                  </TableRow>
                );
              })
            ) : (
              <TableRow><TableCell colSpan={7} align="center" sx={{ py: 5 }}>조건에 맞는 데이터가 없습니다.</TableCell></TableRow>
            )}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
}

export default Violation;
