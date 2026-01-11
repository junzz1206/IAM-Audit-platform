import axios from 'axios';

// 1. 로그인 담당 (Auth Service) -> 8001번
export const authApi = axios.create({
  baseURL: 'http://localhost:8001',
  headers: { 'Content-Type': 'application/json' },
});

// 2. 데이터 담당 (Audit Service) -> 8002번
export const auditApi = axios.create({
  baseURL: 'http://localhost:8002',
  headers: { 'Content-Type': 'application/json' },
});

// 3. 대시보드도 데이터 담당 친구(8002번)한테 물어보게 설정
export const coreApi = auditApi; 

// 기본 내보내기는 필요 없지만 혹시 몰라 auditApi로 연결
export default auditApi;
