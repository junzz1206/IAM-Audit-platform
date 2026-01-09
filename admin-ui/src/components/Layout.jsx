import React from 'react';
import { Outlet } from 'react-router-dom';
import { Box, AppBar, Toolbar, Typography, IconButton, CssBaseline } from '@mui/material';

// 아이콘들 (알림 아이콘 삭제함!)
import MenuIcon from '@mui/icons-material/Menu';
import AccountCircle from '@mui/icons-material/AccountCircle';

import Sidebar from './Sidebar'; 

function Layout() {
  const userRole = localStorage.getItem('userRole') || 'GUEST';
  const commonFont = { fontFamily: '"Noto Sans KR", sans-serif' };

  // 헤더바 컴포넌트
  const HeaderBar = () => (
    <AppBar 
      position="static" 
      elevation={0} 
      sx={{ 
        bgcolor: '#2c3e50', // 차분한 미드나잇 블루
        borderRadius: 0, 
        zIndex: 1201
      }}
    > 
      <Toolbar>
        {/* 왼쪽 햄버거 메뉴 */}
        <IconButton edge="start" color="inherit" aria-label="menu" sx={{ mr: 2 }}>
          <MenuIcon />
        </IconButton>
        
        {/* 가운데 타이틀 */}
        <Typography variant="h6" component="div" sx={{ flexGrow: 1, fontWeight: 'bold', letterSpacing: 1, ...commonFont }}>
          Secure IAM Platform
        </Typography>

        {/* 오른쪽 사용자 정보 (알림 아이콘 삭제됨) */}
        <Box display="flex" alignItems="center" gap={1} ml={2}>
          <Typography variant="body2" sx={{ fontWeight: 500, ...commonFont }}>
            {userRole === 'INFRA' ? '인프라 관리자' : '재무 담당자'} 님
          </Typography>
          <AccountCircle fontSize="large" />
        </Box>
      </Toolbar>
    </AppBar>
  );

  return (
    <Box sx={{ display: 'flex', height: '100vh', overflow: 'hidden' }}>
      
      {/* 브라우저 기본 여백 제거 */}
      <CssBaseline />

      {/* 1. 사이드바 */}
      <Sidebar />

      {/* 2. 오른쪽 영역 */}
      <Box sx={{ flexGrow: 1, display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden' }}>
        
        {/* (A) 헤더 */}
        <HeaderBar />

        {/* (B) 콘텐츠 영역 */}
        <Box 
          component="main" 
          sx={{ 
            flexGrow: 1, 
            p: 3, 
            overflow: 'auto', 
            bgcolor: '#f5f7fa' 
          }}
        >
          <Outlet />
        </Box>

      </Box>
    </Box>
  );
}

export default Layout;
