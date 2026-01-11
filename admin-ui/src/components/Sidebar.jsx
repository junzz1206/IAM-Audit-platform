import React from 'react';
import { Drawer, List, ListItem, ListItemIcon, ListItemText, Toolbar, Divider, Box, Button, Typography } from '@mui/material';
import DashboardIcon from '@mui/icons-material/Dashboard';
import SettingsInputComponentIcon from '@mui/icons-material/SettingsInputComponent'; // 운영 콘솔 아이콘
import CloudUploadIcon from '@mui/icons-material/CloudUpload';
import WarningIcon from '@mui/icons-material/Warning';
import SecurityIcon from '@mui/icons-material/Security';
// PolicyIcon은 이제 안 쓰니까 지워도 돼!
import LogoutIcon from '@mui/icons-material/Logout';
import { useNavigate, useLocation } from 'react-router-dom';

const drawerWidth = 240;

function Sidebar() {
  const navigate = useNavigate();
  const location = useLocation();
  const userRole = localStorage.getItem('userRole') || 'GUEST';

  const handleLogout = () => {
    localStorage.removeItem('userRole');
    navigate('/login');
  };

  return (
    <Drawer
      variant="permanent"
      sx={{
        width: drawerWidth,
        flexShrink: 0,
        [`& .MuiDrawer-paper`]: { width: drawerWidth, boxSizing: 'border-box' },
      }}
    >
      <Toolbar>
        <Typography variant="h6" noWrap component="div" sx={{ color: '#1976d2', fontWeight: 'bold' }}>
          IAM & Audit
        </Typography>
      </Toolbar>
      <Divider />
      
      <List>
        {/* 1. 홈 메뉴 (역할에 따라 이름 변경) */}
        <ListItem button selected={location.pathname === '/'} onClick={() => navigate('/')}>
          <ListItemIcon>
            {userRole === 'INFRA' ? <SettingsInputComponentIcon /> : <DashboardIcon />}
          </ListItemIcon>
          <ListItemText primary={userRole === 'INFRA' ? "운영 콘솔" : "대시보드"} />
        </ListItem>

        {/* 2. 재무팀 전용 */}
        {userRole === 'FINANCE' && (
          <>
            <ListItem button selected={location.pathname === '/upload'} onClick={() => navigate('/upload')}>
              <ListItemIcon><CloudUploadIcon /></ListItemIcon>
              <ListItemText primary="법인카드 업로드" />
            </ListItem>
            <ListItem button selected={location.pathname === '/violation'} onClick={() => navigate('/violation')}>
              <ListItemIcon><WarningIcon /></ListItemIcon>
              <ListItemText primary="규정 위반 내역" />
            </ListItem>
          </>
        )}

        {/* 3. 인프라팀 전용 */}
        {userRole === 'INFRA' && (
          <>
            <ListItem button selected={location.pathname === '/audit'} onClick={() => navigate('/audit')}>
              <ListItemIcon><SecurityIcon /></ListItemIcon>
              <ListItemText primary="감사 로그" />
            </ListItem>
            
            {/* 🗑️ [삭제됨] 정책 관리 (Cilium) 메뉴는 이제 없습니다! 아주 깔끔! */}
          </>
        )}
      </List>

      <Box sx={{ flexGrow: 1 }} />
      <Box p={2}>
        <Button fullWidth variant="outlined" color="error" startIcon={<LogoutIcon />} onClick={handleLogout}>
          로그아웃
        </Button>
      </Box>
    </Drawer>
  );
}
export default Sidebar;
