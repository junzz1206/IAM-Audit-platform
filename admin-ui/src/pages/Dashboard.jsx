import React, { useEffect, useState } from 'react';
import { 
  Typography, Box, Grid, Card, CardContent, Paper, CircularProgress, 
  Button, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, 
  Chip 
} from '@mui/material';

// 차트 라이브러리
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, LabelList } from 'recharts';

// 아이콘 모음
import OpenInNewIcon from '@mui/icons-material/OpenInNew';
import StorageIcon from '@mui/icons-material/Storage';
import RouterIcon from '@mui/icons-material/Router';
import MonitorHeartIcon from '@mui/icons-material/MonitorHeart';
import RuleIcon from '@mui/icons-material/Rule';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import ErrorIcon from '@mui/icons-material/Error';
import DnsIcon from '@mui/icons-material/Dns';                
import RocketLaunchIcon from '@mui/icons-material/RocketLaunch'; 
import NotificationsActiveIcon from '@mui/icons-material/NotificationsActive'; 
import AccountBalanceIcon from '@mui/icons-material/AccountBalance'; 
import WarningAmberIcon from '@mui/icons-material/WarningAmber';    
import BusinessIcon from '@mui/icons-material/Business';            

import { coreApi } from '../api/axios';

// 공통 카드 컴포넌트
function StatCard({ title, value, subText, statusColor, icon, onClick }) {
  return (
    <Card 
      sx={{ 
        minWidth: 200, 
        bgcolor: statusColor || '#1976d2', 
        color: 'white', 
        borderRadius: 3, 
        boxShadow: '0 4px 20px 0 rgba(0,0,0,0.12)', 
        cursor: onClick ? 'pointer' : 'default',
        position: 'relative',
        overflow: 'hidden',
        transition: 'transform 0.2s',
        '&:hover': onClick ? { transform: 'translateY(-5px)', boxShadow: '0 8px 25px 0 rgba(0,0,0,0.2)' } : {}
      }}
      onClick={onClick}
    >
      <CardContent>
        <Typography variant="subtitle1" sx={{ opacity: 0.9, fontWeight: 500 }}>{title}</Typography>
        
        <Box display="flex" alignItems="center" gap={1} mt={1}>
          <Typography variant="h4" fontWeight="bold">{value}</Typography>
          {icon && <Box sx={{ opacity: 0.8, transform: 'scale(1.5)', ml: 1 }}>{icon}</Box>}
        </Box>

        {subText && <Typography variant="caption" sx={{ opacity: 0.85, display: 'block', mt: 1 }}>{subText}</Typography>}
      </CardContent>
    </Card>
  );
}

function Dashboard() {
  const [loading, setLoading] = useState(true);
  const userRole = localStorage.getItem('userRole') || 'GUEST';

  const [financeStats, setFinanceStats] = useState({
    total_transactions: 0,
    violation_count: 0,
    system_status: 'LOADING', 
    daily_violations: [], 
    department_stats: []
  });
  const [infraStats, setInfraStats] = useState(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        if (userRole === 'INFRA') {
          const res = await coreApi.get('/dashboard/infra');
          setInfraStats(res.data);
        } else {
          const res = await coreApi.get('/dashboard/stats');
          setFinanceStats(res.data);
        }
      } catch (error) {
        console.error("데이터 로딩 실패:", error);
        // 에러 나도 화면 깨지지 않게 빈 객체 세팅
        if (userRole === 'INFRA') setInfraStats({});
      } finally {
        // 🔥 [핵심] 성공하든 실패하든 로딩은 무조건 끝낸다! (화면 보여주기 위해)
        setLoading(false);
      }
    };
    fetchData();
  }, [userRole]);

  const commonFont = { fontFamily: '"Noto Sans KR", sans-serif' };
  
  const titleStyle = { 
    display: 'flex', 
    alignItems: 'center', 
    gap: 1.5, 
    fontWeight: 'bold', 
    color: 'text.primary', 
    mb: 3
  };

  if (loading) return <Box display="flex" justifyContent="center" p={10}><CircularProgress /></Box>;

  // -------------------------------------------------------------------------
  // [View 1] 인프라팀 전용 화면
  // -------------------------------------------------------------------------
  if (userRole === 'INFRA') {
    // 데이터가 없으면 기본값 사용 (화면 안 깨지게 방어)
    const stats = infraStats || {};
    const status_summary = stats.status_summary || {
        alert: { critical: 0, warning: 0 },
        eks: { nodes_ready: 0, pods_crash: 0 },
        vpn: { status: "CHECK", latency: "-" },
        db: { usage_percent: 0, blocked: false }
    };
    const recent_events = stats.recent_events || [];
    const quick_links = stats.quick_links || {};

    const getStatusColor = (val, isGoodCondition) => {
        if (val === "CHECK" || val === "연결 실패" || (typeof val === 'string' && val.includes("실패"))) return '#757575'; 
        return isGoodCondition ? '#2e7d32' : '#d32f2f'; 
    };

    const openLink = (url) => {
      if (!url || url === "#") return;
      window.open(url, '_blank');
    };

    return (
      <Box sx={commonFont}>
        <Typography variant="h4" gutterBottom sx={titleStyle}>
          <DnsIcon fontSize="large" color="primary" sx={{ color: 'black' }} /> 인프라 운영 콘솔
        </Typography>
        
        <Grid container spacing={3} mb={4}>
          <Grid item xs={12} md={3}>
            <StatCard 
              title="Alert 요약" 
              value={`${status_summary.alert.critical} Critical`} 
              subText={`${status_summary.alert.warning} Warnings`}
              statusColor={getStatusColor(status_summary.alert.critical, status_summary.alert.critical === 0)}
              onClick={() => openLink(quick_links.grafana_cluster)}
            />
          </Grid>
          <Grid item xs={12} md={3}>
            <StatCard 
              title="EKS 상태" 
              value={`${status_summary.eks.nodes_ready} Nodes Ready`} 
              subText={`${status_summary.eks.pods_crash} Pods CrashLoop`}
              statusColor={getStatusColor(status_summary.eks.nodes_ready, status_summary.eks.pods_crash === 0)}
              onClick={() => openLink(quick_links.grafana_cluster)}
            />
          </Grid>
          <Grid item xs={12} md={3}>
            <StatCard 
              title="하이브리드 터널" 
              value={status_summary.vpn.status} 
              subText={`Latency: ${status_summary.vpn.latency}`}
              statusColor={getStatusColor(status_summary.vpn.status, status_summary.vpn.status === 'UP')}
            />
          </Grid>
          <Grid item xs={12} md={3}>
            <StatCard 
              title="DB 연결 상태" 
              value={`${status_summary.db.usage_percent}% 사용중`} 
              subText={status_summary.db.blocked ? "Blocked Session 감지됨!" : "세션 상태 양호"}
              statusColor={getStatusColor(status_summary.db.usage_percent, !status_summary.db.blocked)}
              onClick={() => openLink(quick_links.grafana_db)}
            />
          </Grid>
        </Grid>

        <Typography variant="h6" gutterBottom sx={{ ...titleStyle, mt: 5, mb: 2 }}>
          <RocketLaunchIcon color="secondary" /> 퀵 메뉴 (Quick Links)
        </Typography>
        
        <Grid container spacing={2} mb={5}>
          {[
            { name: "Grafana (Cluster)", icon: <MonitorHeartIcon />, url: quick_links.grafana_cluster },
            { name: "Grafana (DB)", icon: <StorageIcon />, url: quick_links.grafana_db },
            { name: "Hubble (Network)", icon: <RouterIcon />, url: quick_links.hubble },
            { name: "Loki (Logs)", icon: <StorageIcon />, url: quick_links.loki },
            { name: "ArgoCD", icon: <OpenInNewIcon />, url: quick_links.argocd },
            { name: "Runbook", icon: <RuleIcon />, url: quick_links.runbook },
          ].map((item, idx) => (
            <Grid item xs={6} md={2} key={idx}>
              <Button 
                variant="outlined" 
                fullWidth 
                sx={{ 
                  height: 90, display: 'flex', flexDirection: 'column', gap: 1, 
                  textTransform: 'none', borderColor: '#e0e0e0', color: '#424242', 
                  bgcolor: 'white', borderRadius: 2, boxShadow: 1,
                  '&:hover': { bgcolor: '#e3f2fd', borderColor: '#2196f3' },
                  ...commonFont 
                }}
                onClick={() => openLink(item.url)}
              >
                <Box color="#1565c0">{item.icon}</Box>
                <Typography variant="body2" fontWeight="600">{item.name}</Typography>
              </Button>
            </Grid>
          ))}
        </Grid>

        <Typography variant="h6" gutterBottom sx={{ ...titleStyle, mb: 2 }}>
          <NotificationsActiveIcon color="warning" /> 최근 이벤트 (Recent Events)
        </Typography>
        <TableContainer component={Paper} elevation={3} sx={{ borderRadius: 3, overflow: 'hidden', mb: 10 }}>
          <Table size="small">
            <TableHead sx={{ bgcolor: '#eceff1' }}>
              <TableRow>
                <TableCell width="15%" sx={{ fontWeight: 'bold' }}>시간</TableCell>
                <TableCell width="10%" align="center" sx={{ fontWeight: 'bold' }}>심각도</TableCell>
                <TableCell width="20%" sx={{ fontWeight: 'bold' }}>대상 (Target)</TableCell>
                <TableCell sx={{ fontWeight: 'bold' }}>메시지</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {recent_events.length > 0 ? recent_events.map((evt, idx) => (
                <TableRow key={idx} hover>
                  <TableCell sx={commonFont}>{evt.time}</TableCell>
                  <TableCell align="center">
                    <Chip 
                      label={evt.severity} 
                      color={evt.severity === 'CRITICAL' ? 'error' : evt.severity === 'WARNING' ? 'warning' : 'info'} 
                      size="small" 
                      sx={{ fontWeight: 'bold', fontSize: '0.7rem' }}
                    />
                  </TableCell>
                  <TableCell sx={{ fontWeight: 'bold', color: '#555', ...commonFont }}>{evt.target}</TableCell>
                  <TableCell sx={commonFont}>{evt.message}</TableCell>
                </TableRow>
              )) : (
                <TableRow>
                  <TableCell colSpan={4} align="center" sx={{ py: 3, color: '#999' }}>
                    최근 이벤트가 없습니다.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </TableContainer>
      </Box>
    );
  }

  // -------------------------------------------------------------------------
  // [View 2] 재무팀 전용 화면
  // -------------------------------------------------------------------------
  return (
    <Box sx={commonFont}>
      <Typography variant="h4" gutterBottom sx={titleStyle}>
        <AccountBalanceIcon fontSize="large" color="primary" sx={{ color: 'black' }} /> 재무 관리 대시보드
      </Typography>

      <Grid container spacing={3} mb={5}>
        <Grid item xs={12} md={4}>
          <StatCard 
            title="전체 거래 건수" 
            value={`${financeStats.total_transactions || 0}건`} 
            statusColor="#1565c0" 
          /> 
        </Grid>
        <Grid item xs={12} md={4}>
          <StatCard 
            title="규정 위반 건수" 
            value={`${financeStats.violation_count || 0}건`} 
            statusColor="#c62828" 
          />
        </Grid>
        <Grid item xs={12} md={4}>
          <StatCard 
            title="시스템 상태" 
            value={financeStats.system_status === 'NORMAL' ? "정상" : "점검"} 
            statusColor={financeStats.system_status === 'NORMAL' ? "#2e7d32" : "#d32f2f"}
            icon={financeStats.system_status === 'NORMAL' ? <CheckCircleIcon /> : <ErrorIcon />} 
          />
        </Grid>
      </Grid>

      <Grid container spacing={3}>
        <Grid item xs={12} md={6}>
          <Typography variant="h6" gutterBottom sx={titleStyle}>
            <WarningAmberIcon color="error" /> 최근 7일 규정 위반
          </Typography>
          <Paper sx={{ p: 3, borderRadius: 3, height: 350, minWidth: 500, boxShadow: 3 }} elevation={0}>
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={financeStats.daily_violations || []} margin={{ top: 20, right: 20, left: 20, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} />
                <XAxis dataKey="day" interval={0} padding={{ left: 20, right: 20 }} />
                <YAxis allowDecimals={false} />
                <Tooltip wrapperStyle={{ border: '1px solid #d32f2f', borderRadius: '8px' }} />
                <Bar dataKey="count" fill="#e53935" name="위반 횟수" radius={[5, 5, 0, 0]} barSize={50}>
                    <LabelList dataKey="count" position="top" fill="#d32f2f" fontWeight="bold" />
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </Paper>
        </Grid>

        <Grid item xs={12} md={6}>
          <Typography variant="h6" gutterBottom sx={titleStyle}>
            <BusinessIcon color="secondary" /> 부서별 위반 현황
          </Typography>
          <Paper sx={{ p: 3, borderRadius: 3, height: 350, minWidth: 500, boxShadow: 3 }} elevation={0}>
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={financeStats.department_stats || []} margin={{ top: 20, right: 20, left: 20, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} />
                <XAxis dataKey="name" interval={0} padding={{ left: 20, right: 20 }} />
                <YAxis allowDecimals={false} />
                <Tooltip wrapperStyle={{ border: '1px solid #7b1fa2', borderRadius: '8px' }} />
                <Bar dataKey="value" fill="#8e24aa" name="위반 횟수" radius={[5, 5, 0, 0]} barSize={50}>
                  <LabelList dataKey="value" position="top" fill="#7b1fa2" fontWeight="bold" />
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </Paper>
        </Grid>
      </Grid>
    </Box>
  );
}

export default Dashboard;
