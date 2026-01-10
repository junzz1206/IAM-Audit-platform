import React, { useState } from 'react';
import { Box, Button, Typography, Paper, Container, TextField, Alert } from '@mui/material';
import { useNavigate } from 'react-router-dom'; // 페이지 이동 훅 추가
import { authApi } from '../api/axios';

function Login() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [errorMsg, setErrorMsg] = useState('');
  
  const navigate = useNavigate(); // 페이지 이동 함수

  // [중요] 이벤트 객체(e)를 받아서 새로고침을 막아야 함!
  const handleLogin = async (e) => {
    e.preventDefault(); // 1. 폼 제출 시 새로고침 방지 (필수!)
    setErrorMsg('');    // 에러 메시지 초기화

    try {
      console.log("로그인 시도:", username); // 확인용 로그

      // 2. 백엔드 요청
      const response = await authApi.post('/auth/login', {
        username: username,
        password: password
      });

      console.log("로그인 성공 응답:", response.data);

      // 3. 토큰과 역할 저장
      const token = response.data.access_token || response.data.token;
      const role = response.data.role || response.data.role_name;

      localStorage.setItem('authToken', token);
      localStorage.setItem('userRole', role);

      // 4. 역할에 따라 안내 메시지 (생략 가능)
      if(role === 'INFRA') alert("인프라 팀장님 환영합니다! 🛠️");
      else if(role === 'FINANCE') alert("재무 팀장님 환영합니다! 💰");

      // 5. 대시보드로 이동 (새로고침 없이!)
      // window.location.href = "/" 대신 navigate 사용
      navigate("/dashboard"); 

    } catch (err) {
      console.error("로그인 에러:", err);
      // 백엔드에서 401(비번틀림) 등을 주면 여기서 잡힘
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

        {/* 폼 태그에 onSubmit 연결 */}
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
            type="submit" // 엔터 쳐도 로그인 되게 함
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
            {/* ★★★ 중요: 재무팀 아이디는 'admin'일 수 있음! ★★★ */}
            재무팀: <b>admin</b> (또는 finance) / <b>1234</b>
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
