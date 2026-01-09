import React from 'react';
import { BrowserRouter, Routes, Route, Navigate, Outlet } from 'react-router-dom';
import Layout from './components/Layout';
import Dashboard from './pages/Dashboard';
import CardUpload from './pages/CardUpload';
import Violation from './pages/Violation';
import AuditLog from './pages/AuditLog';
import Login from './pages/Login'; // 로그인 페이지 추가

// 로그인이 필요한 페이지를 감싸는 보호막 컴포넌트
const ProtectedRoute = () => {
  const userRole = localStorage.getItem('userRole');
  // 역할(Role)이 없으면 로그인 페이지로 강제 이동
  if (!userRole) {
    return <Navigate to="/login" replace />;
  }
  // 역할이 있으면 원래 가려던 페이지(Outlet) 보여줌
  return <Outlet />;
};

function App() {
  return (
    <BrowserRouter>
      <Routes>
        {/* 1. 로그인 페이지 (Layout 없이 꽉 찬 화면) */}
        <Route path="/login" element={<Login />} />

        {/* 2. 메인 페이지들 (Layout + Sidebar 적용) */}
        {/* ProtectedRoute로 감싸서, 로그인 안 하면 접근 불가! */}
        <Route element={<ProtectedRoute />}>
          <Route path="/" element={<Layout />}>
            <Route index element={<Dashboard />} />
            <Route path="upload" element={<CardUpload />} />
            <Route path="violation" element={<Violation />} />
            <Route path="audit" element={<AuditLog />} />
          </Route>
        </Route>

        {/* 3. 이상한 주소로 오면 대시보드로 보냄 */}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
