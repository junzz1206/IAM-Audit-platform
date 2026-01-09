import React, { useEffect, useState } from 'react';
import { Typography, Box, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Paper, Chip, Avatar, CircularProgress } from '@mui/material';
// 8002번 포트 API 가져오기
import { auditApi } from '../api/axios';

function AuditLog() {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);

  // 서버에서 로그 가져오기
  useEffect(() => {
    const fetchLogs = async () => {
      try {
        // 백엔드: GET /logs (Audit Service)
        const response = await auditApi.get('/logs');
        setLogs(response.data);
      } catch (error) {
        console.error("로그 로딩 실패:", error);
      } finally {
        setLoading(false);
      }
    };
    fetchLogs();
  }, []);

  return (
    <Box>
      <Typography variant="h4" gutterBottom fontWeight="bold">
        보안 감사 로그 (Audit)
      </Typography>
      <Typography mb={3} color="textSecondary">
        시스템의 모든 접근 및 행위 이력을 상세 조회합니다. (위반 내역 제외)
      </Typography>
      
      <TableContainer component={Paper} elevation={3} sx={{ borderRadius: 2, overflow: 'hidden' }}>
        <Table sx={{ minWidth: 650 }}>
          <TableHead sx={{ bgcolor: '#f5f5f5' }}>
            <TableRow>
              <TableCell>시간</TableCell>
              <TableCell align="center">구분</TableCell>
              <TableCell>행위자 (ID)</TableCell>
              <TableCell>접속 IP</TableCell>
              <TableCell>내용</TableCell>
              <TableCell align="center">상태</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {loading ? (
              <TableRow><TableCell colSpan={6} align="center" sx={{ py: 5 }}><CircularProgress /></TableCell></TableRow>
            ) : logs.map((row, index) => (
              <TableRow key={row.id || row.log_id || index} hover>
                {/* 백엔드 필드명(timestamp)과 매칭 */}
                <TableCell>{row.timestamp || row.time}</TableCell>
                <TableCell align="center">
                  <Chip 
                    label={row.service_name || 'SYSTEM'} 
                    variant="outlined" size="small" 
                    color="primary" 
                  />
                </TableCell>
                <TableCell>
                  <Box display="flex" alignItems="center" gap={1}>
                    <Avatar sx={{ width: 24, height: 24, fontSize: 12 }}>
                      {(row.user_id || row.user || 'S')[0].toUpperCase()}
                    </Avatar>
                    <Typography fontWeight="bold">{row.user_id || row.user || 'System'}</Typography>
                  </Box>
                </TableCell>
                <TableCell sx={{ fontFamily: 'monospace', color: '#666' }}>{row.ip_address || row.ip}</TableCell>
                <TableCell>{row.action}</TableCell>
                <TableCell align="center">
                  {/* 심각도(severity)에 따라 색상 자동 결정 */}
                  <Chip 
                    label={row.severity || row.status || 'INFO'} 
                    color={
                      (row.severity === 'ERROR' || row.status === 'FAIL') ? 'error' : 
                      (row.severity === 'WARNING') ? 'warning' : 
                      (row.severity === 'SUCCESS') ? 'success' : 'primary'
                    } 
                    size="small" 
                    sx={{ fontWeight: 'bold', borderRadius: 1, minWidth: 80 }}
                  />
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
}

export default AuditLog;
