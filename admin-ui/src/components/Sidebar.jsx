import React from 'react';
import { 
  Drawer, List, ListItem, ListItemButton, ListItemIcon, ListItemText, 
  Toolbar, Divider, Box, Button, Typography 
} from '@mui/material'; // 🌟 import를 하나로 깔끔하게 합쳤어요!
import DashboardIcon from '@mui/icons-material/Dashboard';
import SettingsInputComponentIcon from '@mui/icons-material/SettingsInputComponent'; 
import CloudUploadIcon from '@mui/icons-material/CloudUpload';
import WarningIcon from '@mui/icons-material/Warning';
import SecurityIcon from '@mui/icons-material/Security';
import LogoutIcon from '@mui/icons-material/Logout';
import { useNavigate, useLocation } from 'react-router-dom';
import axios from 'axios'; 

const drawerWidth = 240;

function Sidebar() {
  const navigate = useNavigate();
  const location = useLocation();
  const userRole = localStorage.getItem('userRole') || 'GUEST';
  const username = localStorage.getItem('username') || 'unknown';

  const handleLogout = async () => {
    try {
      await axios.post('http://localhost:8002/logs', {
        event_type: 'LOGIN',     
        actor_id: username,      
        actor_type: 'USER',      
        source_ip: 'Client',     
        action: 'LOGOUT',        
        result: 'SUCCESS',       
        target_id: 'System_Auth',
        target_type: 'SYSTEM'
      });
      console.log("로그아웃 로그 전송 성공");
    } catch (error) {
      console.error("로그아웃 로그 전송 실패:", error);
    } finally {
      localStorage.removeItem('authToken');
      localStorage.removeItem('userRole');
      localStorage.removeItem('username');
      navigate('/login');
    }
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
        {/* 1. 대시보드 / 운영 콘솔 */}
        <ListItem disablePadding>
          <ListItemButton 
            selected={location.pathname === '/'} 
            onClick={() => navigate('/')}
          >
            <ListItemIcon>
              {userRole === 'INFRA' ? <SettingsInputComponentIcon /> : <DashboardIcon />}
            </ListItemIcon>
            <ListItemText primary={userRole === 'INFRA' ? "운영 콘솔" : "대시보드"} />
          </ListItemButton>
        </ListItem>

        {/* 2. 재무팀(FINANCE) 메뉴 */}
        {userRole === 'FINANCE' && (
          <>
            <ListItem disablePadding>
              <ListItemButton 
                selected={location.pathname === '/upload'} 
                onClick={() => navigate('/upload')}
              >
                <ListItemIcon><CloudUploadIcon /></ListItemIcon>
                <ListItemText primary="법인카드 업로드" />
              </ListItemButton>
            </ListItem>

            <ListItem disablePadding>
              <ListItemButton 
                selected={location.pathname === '/violation'} 
                onClick={() => navigate('/violation')}
              >
                <ListItemIcon><WarningIcon /></ListItemIcon>
                <ListItemText primary="규정 위반 내역" />
              </ListItemButton>
            </ListItem>
          </>
        )}

        {/* 3. 인프라팀(INFRA) 메뉴 */}
        {userRole === 'INFRA' && (
          <ListItem disablePadding>
            <ListItemButton 
              selected={location.pathname === '/audit'} 
              onClick={() => navigate('/audit')}
            >
              <ListItemIcon><SecurityIcon /></ListItemIcon>
              <ListItemText primary="감사 로그" />
            </ListItemButton>
          </ListItem>
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