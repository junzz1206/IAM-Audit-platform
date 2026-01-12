import axios from 'axios';

// 1. 금융/대시보드 서비스 (Core Service - 8000번)
export const coreApi = axios.create({
  baseURL: 'http://localhost:8000',
  headers: { 'Content-Type': 'application/json' }
});

// 2. 인증 서비스 (Auth Service - 8001번)
export const authApi = axios.create({
  baseURL: 'http://localhost:8001',
  headers: { 'Content-Type': 'application/json' }
});

// 3. 🌟 [추가됨] 감사 로그 서비스 (Audit Service - 8002번)
export const auditApi = axios.create({
  baseURL: 'http://localhost:8002',
  headers: { 'Content-Type': 'application/json' }
});

// 요청을 보낼 때마다 토큰(신분증)이 있으면 자동으로 끼워넣기
const addTokenInterceptor = (instance) => {
  instance.interceptors.request.use((config) => {
    const token = localStorage.getItem('authToken');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  });
};

// 모든 API에 토큰 기능 장착
addTokenInterceptor(coreApi);
addTokenInterceptor(authApi);
addTokenInterceptor(auditApi);