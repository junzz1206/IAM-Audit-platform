import React, { useState, useEffect } from 'react';
import { 
  Typography, Box, Table, TableBody, TableCell, TableContainer, 
  TableHead, TableRow, Paper, Chip, Grid, TextField, Button, InputAdornment, CircularProgress, Tooltip, Stack,
  FormControl, Select, MenuItem, InputLabel
} from '@mui/material';
import SecurityIcon from '@mui/icons-material/Security'; // 🌟 아이콘 변경 (카드 -> 보안)
import SearchIcon from '@mui/icons-material/Search';
import RefreshIcon from '@mui/icons-material/Refresh';
import FilterListIcon from '@mui/icons-material/FilterList'; 
import SortIcon from '@mui/icons-material/Sort';

// 필터 칩용 아이콘
import FormatListBulletedIcon from '@mui/icons-material/FormatListBulleted'; 
import CheckCircleIcon from '@mui/icons-material/CheckCircle'; 
import ErrorIcon from '@mui/icons-material/Error'; 

import axios from 'axios';

function AuditLog() {
  const [rows, setRows] = useState([]); 
  const [filteredRows, setFilteredRows] = useState([]); 
  const [loading, setLoading] = useState(true);

  // 검색/필터 상태
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [keyword, setKeyword] = useState('');
  const [filterType, setFilterType] = useState('ALL'); // ALL, SUCCESS, FAILURE
  const [sortOrder, setSortOrder] = useState('NEWEST'); // 🌟 기본값: 최신순

  // 1. 데이터 가져오기
  const fetchLogs = async () => {
    try {
      setLoading(true);
      const response = await axios.get('http://localhost:8002/logs');
      setRows(response.data);
      // 데이터 가져오자마자 필터 적용
      applyFilters(response.data, filterType, startDate, endDate, keyword, sortOrder);
    } catch (error) {
      console.error("로그 로딩 실패:", error);
      setRows([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLogs();
  }, []);

  // 2. 상태 변경 시 필터링 자동 적용
  useEffect(() => {
    applyFilters(rows, filterType, startDate, endDate, keyword, sortOrder);
  }, [rows, filterType, startDate, endDate, keyword, sortOrder]);

  // 3. 필터링 및 정렬 로직
  const applyFilters = (data, type, start, end, key, sort) => {
    let result = data.filter((row) => {
      // 날짜 필터링
      const rowDate = row.created_at ? row.created_at.split('T')[0] : '';
      const isAfterStart = start ? rowDate >= start : true;
      const isBeforeEnd = end ? rowDate <= end : true;

      // 키워드 검색 (ID, IP, 행동, 타겟)
      const query = key.toLowerCase();
      const matchesKeyword = 
        (row.actor_id && row.actor_id.toLowerCase().includes(query)) || 
        (row.source_ip && row.source_ip.toLowerCase().includes(query)) ||
        (row.action && row.action.toLowerCase().includes(query)) ||
        (row.target_id && row.target_id.toLowerCase().includes(query));

      if (!isAfterStart || !isBeforeEnd || !matchesKeyword) return false;

      // 상태 필터링 (칩 버튼)
      if (type === 'ALL') return true;
      if (type === 'SUCCESS') return row.result === 'SUCCESS';
      if (type === 'FAILURE') return row.result === 'FAILURE';

      return true;
    });

    // 정렬 로직
    result.sort((a, b) => {
      const dateA = new Date(a.created_at);
      const dateB = new Date(b.created_at);
      
      if (sort === 'NEWEST') {
        return dateB - dateA; // 최신순 (내림차순)
      } else {
        return dateA - dateB; // 과거순 (오름차순)
      }
    });

    setFilteredRows(result);
  };

  // 4. 초기화 버튼
  const handleReset = () => {
    setStartDate('');
    setEndDate('');
    setKeyword('');
    setFilterType('ALL');
    setSortOrder('NEWEST');
  };

  return (
    <Box>
      {/* 헤더 (Violation.jsx와 동일한 스타일) */}
      <Typography variant="h4" gutterBottom fontWeight="bold" color="text.primary" sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
        <SecurityIcon fontSize="large" sx={{ color: 'black' }} /> 
        보안 감사 로그 (Audit)
      </Typography>
      <Typography mb={3} color="textSecondary">
        시스템의 모든 접근 및 중요 행위 이력을 조회하고, <strong>보안 위협</strong>을 모니터링합니다.
      </Typography>

      {/* 검색 필터 영역 (Violation.jsx와 완벽 동일) */}
      <Paper sx={{ p: 3, mb: 4, bgcolor: '#fff', borderRadius: 2 }} elevation={1}>
        <Grid container spacing={2} alignItems="center">
          {/* 날짜 검색 */}
          <Grid item xs={12} md={3}>
            <Box display="flex" gap={1} alignItems="center">
              <TextField type="date" size="small" fullWidth value={startDate} onChange={(e) => setStartDate(e.target.value)} label="시작일" InputLabelProps={{ shrink: true }} />
              <Typography>~</Typography>
              <TextField type="date" size="small" fullWidth value={endDate} onChange={(e) => setEndDate(e.target.value)} label="종료일" InputLabelProps={{ shrink: true }} />
            </Box>
          </Grid>
          
          {/* 키워드 검색 */}
          <Grid item xs={12} md={3}>
            <TextField fullWidth size="small" placeholder="ID, IP, 행위 검색" value={keyword} onChange={(e) => setKeyword(e.target.value)} InputProps={{ startAdornment: (<InputAdornment position="start"><SearchIcon color="action" /></InputAdornment>) }} />
          </Grid>
          
          {/* 정렬 드롭다운 */}
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
                <MenuItem value="NEWEST">최신순</MenuItem>
                <MenuItem value="OLDEST">과거순</MenuItem>
              </Select>
            </FormControl>
          </Grid>

          {/* 초기화 버튼 */}
          <Grid item xs={12} md={4} display="flex" justifyContent="flex-end">
            <Button variant="outlined" color="inherit" onClick={handleReset} startIcon={<RefreshIcon />}>검색 초기화</Button>
          </Grid>

          {/* 하단 필터 칩 (보기 필터) */}
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
                    label="성공 (Success)" onClick={() => setFilterType('SUCCESS')} 
                    variant={filterType === 'SUCCESS' ? 'filled' : 'outlined'}
                    sx={{ borderColor: '#2e7d32', color: filterType === 'SUCCESS' ? '#fff' : '#2e7d32', bgcolor: filterType === 'SUCCESS' ? '#2e7d32' : 'transparent', fontWeight: 'bold' }} clickable 
                />
                <Chip 
                    icon={<ErrorIcon style={{ color: '#d32f2f' }} />} 
                    label="실패 (Failure)" onClick={() => setFilterType('FAILURE')} 
                    variant={filterType === 'FAILURE' ? 'filled' : 'outlined'}
                    sx={{ borderColor: '#d32f2f', color: filterType === 'FAILURE' ? '#fff' : '#d32f2f', bgcolor: filterType === 'FAILURE' ? '#d32f2f' : 'transparent', fontWeight: 'bold' }} clickable 
                />
              </Stack>
            </Box>
          </Grid>
        </Grid> 
      </Paper>

      {/* 테이블 영역 */}
      <TableContainer component={Paper} elevation={3} sx={{ borderRadius: 2, overflow: 'hidden' }}>
        <Table sx={{ minWidth: 650 }}>
          <TableHead sx={{ bgcolor: '#ffffff', borderBottom: '2px solid #e0e0e0' }}>
            <TableRow>
              <TableCell sx={{ fontWeight: 'bold' }}>일시</TableCell>
              <TableCell sx={{ fontWeight: 'bold' }}>구분 (Event)</TableCell>
              <TableCell sx={{ fontWeight: 'bold' }}>행위자 (ID)</TableCell>
              <TableCell sx={{ fontWeight: 'bold' }}>접속 IP</TableCell>
              <TableCell sx={{ fontWeight: 'bold' }}>행위 (Action)</TableCell>
              <TableCell sx={{ fontWeight: 'bold' }}>대상 (Target)</TableCell>
              <TableCell sx={{ fontWeight: 'bold', textAlign: 'center' }}>결과 (Result)</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {loading ? (
               <TableRow><TableCell colSpan={7} align="center" sx={{ py: 5 }}><CircularProgress /></TableCell></TableRow>
            ) : filteredRows.length > 0 ? (
              filteredRows.map((row, index) => {
                const isFail = row.result === 'FAILURE';
                // 실패한 로그는 붉은색 배경 (Violation과 동일한 UX)
                const rowBgColor = isFail ? '#fff5f5' : 'inherit';

                return (
                  <TableRow key={index} hover sx={{ bgcolor: rowBgColor }}>
                    <TableCell>{new Date(row.created_at).toLocaleString()}</TableCell>
                    <TableCell>
                      <Chip 
                        label={row.event_type} 
                        size="small" 
                        color="primary" 
                        variant="outlined" 
                        sx={{ fontWeight: 'bold' }}
                      />
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2" fontWeight="bold">{row.actor_id}</Typography>
                    </TableCell>
                    <TableCell>
                        <Tooltip title="접속 위치 확인">
                            <Box component="span" sx={{ fontFamily: 'monospace', cursor: 'pointer', borderBottom: '1px dotted #999' }}>
                                {row.source_ip}
                            </Box>
                        </Tooltip>
                    </TableCell>
                    <TableCell sx={{ fontWeight: 'bold', color: '#555' }}>
                        {row.action}
                    </TableCell>
                    <TableCell>
                        {row.target_id || '-'}
                    </TableCell>
                    <TableCell align="center">
                      {isFail ? (
                          <Chip 
                            icon={<ErrorIcon />}
                            label="FAILURE" 
                            color="error" 
                            size="small" 
                            sx={{ fontWeight: 'bold', minWidth: 90 }}
                          />
                      ) : (
                          <Chip 
                            icon={<CheckCircleIcon />}
                            label="SUCCESS" 
                            color="success" 
                            size="small" 
                            variant="filled" 
                            sx={{ fontWeight: 'bold', minWidth: 90 }}
                          />
                      )}
                    </TableCell>
                  </TableRow>
                );
              })
            ) : (
              <TableRow><TableCell colSpan={7} align="center" sx={{ py: 5 }}>조건에 맞는 로그가 없습니다.</TableCell></TableRow>
            )}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
}

export default AuditLog;