import React, { useState } from 'react';
import { Box, Button, Typography, Paper, Container, TextField, Alert } from '@mui/material';
import axios from 'axios'; 

function Login() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [errorMsg, setErrorMsg] = useState('');
  
  // const navigate = useNavigate(); // 이번엔 이거 안 쓰고 강제 이동 쓸 거라 주석 처리!

  const handleLogin = async (e) => {
    e.preventDefault(); // 새로고침 방지
    setErrorMsg('');

    try {
      console.log("로그인 시도:", username);

      // 1. 백엔드로 로그인 요청
      const response = await axios.post("http://localhost:8001/auth/login", {
        username: username,
        password: password
      });

      console.log("로그인 성공 응답:", response.data);

      // 2. 데이터 받기
      const { token, role, department } = response.data;

      // 3. 토큰과 역할 저장 (App.js 통행증)
      localStorage.setItem('token', token);
      localStorage.setItem('userRole', role);
      localStorage.setItem('username', username);
      localStorage.setItem('department', department);

      // 4. 환영 메시지
      if(role === 'INFRA') alert(`클라우드운영팀(${department}) 환영합니다! 🛠️`);
      else if(role === 'FINANCE') alert(`재무회계팀(${department}) 환영합니다! 💰`);

      // 🔥 [핵심 수정] 강제로 새로고침하며 이동! (화면 전환 확실하게!)
      window.location.href = "/"; 

    } catch (err) {
      console.error("로그인 에러:", err);
      setErrorMsg("아이디 또는 비밀번호를 확인해주세요!");
    }
  };

  return (
    <Container maxWidth="xs" sx={{ mt: 10 }}>
      <Paper elevation={3} sx={{ p: 4, textAlign: 'center', borderRadius: 3 }}>
        <Typography variant="h5" fontWeight="bold" gutterBottom color="primary">
          IAM System Login
        </Typography>
        
        {errorMsg && <Alert severity="error" sx={{ mb: 2 }}>{errorMsg}</Alert>}

        <Box component="form" onSubmit={handleLogin} display="flex" flexDirection="column" gap={2}>
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
            type="submit" 
            variant="contained" 
            size="large" 
            fullWidth 
            sx={{ bgcolor: '#1976d2', mt: 1, py: 1.5, fontWeight: 'bold' }}
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
