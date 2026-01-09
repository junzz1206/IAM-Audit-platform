import React, { useState } from 'react';
import { Box, Button, Typography, Paper, Container, TextField, Alert } from '@mui/material';
import { authApi } from '../api/axios'; // 방금 만든 API 가져오기

function Login() {
  // 사용자가 입력한 ID/PW를 저장하는 상태
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [errorMsg, setErrorMsg] = useState('');

  const handleLogin = async () => {
    try {
      // 1. 백엔드(Auth Service 8001번)에 로그인 요청 보내기!
      // 진짜 ID/PW를 실어 보냅니다.
      const response = await authApi.post('/auth/login', {
        username: username,
        password: password
      });

      // 2. 성공하면 백엔드가 토큰이랑 역할을 줍니다.
      const { token, role } = response.data;
      
      console.log("로그인 성공!", response.data);

      // 3. 브라우저에 저장 (토큰, 역할)
      localStorage.setItem('authToken', token);
      localStorage.setItem('userRole', role);

      // 4. 메인 페이지로 이동 (새로고침)
      window.location.href = "/"; 

    } catch (err) {
      // 5. 실패하면 에러 메시지 띄우기
      console.error("로그인 실패:", err);
      setErrorMsg("아이디 또는 비밀번호가 틀렸습니다!");
    }
  };

  return (
    <Container maxWidth="xs" sx={{ mt: 10 }}>
      <Paper elevation={3} sx={{ p: 4, textAlign: 'center', borderRadius: 3 }}>
        <Typography variant="h5" fontWeight="bold" gutterBottom color="primary">
          IAM System Login
        </Typography>
        <Typography color="textSecondary" mb={3} variant="body2">
          관리자 승인 계정으로 접속해주세요.
        </Typography>

        {/* 에러 메시지가 있으면 보여줌 */}
        {errorMsg && <Alert severity="error" sx={{ mb: 2 }}>{errorMsg}</Alert>}

        <Box display="flex" flexDirection="column" gap={2}>
          <TextField 
            label="아이디" 
            variant="outlined" 
            fullWidth 
            value={username}
            onChange={(e) => setUsername(e.target.value)}
          />
          <TextField 
            label="비밀번호" 
            type="password" 
            variant="outlined" 
            fullWidth 
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
          
          <Button 
            variant="contained" 
            size="large" 
            fullWidth 
            sx={{ bgcolor: '#1976d2', mt: 1, py: 1.5, fontWeight: 'bold' }}
            onClick={handleLogin}
          >
            로그인 하기
          </Button>
        </Box>

        <Box mt={3} bgcolor="#f5f5f5" p={2} borderRadius={2} textAlign="left">
          <Typography variant="caption" color="textSecondary" display="block">
            [테스트 계정 정보]
          </Typography>
          <Typography variant="caption" display="block">
            재무팀: <b>admin</b> / <b>1234</b>
          </Typography>
          <Typography variant="caption" display="block">
            인프라팀: <b>infra</b> / <b>1234</b>
          </Typography>
        </Box>
      </Paper>
    </Container>
  );
}

export default Login;
