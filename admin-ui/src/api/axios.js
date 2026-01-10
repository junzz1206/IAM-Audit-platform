import axios from 'axios';

// 1. 공통 설정
const instance = axios.create({
  baseURL: 'http://localhost:8000',
  headers: {
    'Content-Type': 'application/json',
  },
});

// 2. 파일들에서 요구하는 이름들로 내보내기 (Export)
export const coreApi = instance;  // Dashboard.jsx용
export const authApi = instance;  // Login.jsx용
export const auditApi = instance; // AuditLog.jsx용

export default instance;
