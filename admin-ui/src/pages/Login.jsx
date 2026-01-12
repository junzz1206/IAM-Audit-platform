import React, { useState } from 'react';
import { Box, TextField, Button, Typography, Paper, Container } from '@mui/material';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';

function Login() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const navigate = useNavigate();

  const handleLogin = async (e) => {
    e.preventDefault();
    try {
      // 로그인 요청
      const response = await axios.post('http://localhost:8001/auth/login', {
        username,
        password
      });

      // ✅ 성공 시 데이터 저장
      const { token, role, username: returnedName } = response.data;
      
      localStorage.setItem('authToken', token);
      localStorage.setItem('userRole', role);
      
      // 🌟 [핵심] 이 줄이 없어서 unknown이 떴던 겁니다! 추가해주세요!
      localStorage.setItem('username', returnedName || username); 

      alert(`환영합니다, ${returnedName || username}님!`);
      navigate('/'); // 메인 페이지로 이동

    } catch (error) {
      console.error(error);
      alert('로그인 실패! 아이디와 비밀번호를 확인하세요.');
    }
  };

  return (
    <Container component="main" maxWidth="xs" sx={{ height: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <Paper elevation={3} sx={{ p: 4, display: 'flex', flexDirection: 'column', alignItems: 'center', width: '100%' }}>
        <Typography component="h1" variant="h5" sx={{ mb: 3, fontWeight: 'bold' }}>
          IAM 시스템 로그인
        </Typography>
        <Box component="form" onSubmit={handleLogin} sx={{ mt: 1, width: '100%' }}>
          <TextField
            margin="normal"
            required
            fullWidth
            label="아이디"
            autoFocus
            value={username}
            onChange={(e) => setUsername(e.target.value)}
          />
          <TextField
            margin="normal"
            required
            fullWidth
            label="비밀번호"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
          <Button
            type="submit"
            fullWidth
            variant="contained"
            sx={{ mt: 3, mb: 2, py: 1.5, fontWeight: 'bold' }}
          >
            로그인
          </Button>
        </Box>
      </Paper>
    </Container>
  );
}

export default Login;