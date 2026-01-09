import React, { useState, useRef } from 'react';
import { Typography, Box, Button, Paper, Divider, Alert, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, CircularProgress } from '@mui/material';
import FileDownloadIcon from '@mui/icons-material/FileDownload'; 
import DescriptionIcon from '@mui/icons-material/Description'; 
import InfoIcon from '@mui/icons-material/Info';
import CloudUploadIcon from '@mui/icons-material/CloudUpload';
// 백엔드 API (이미 만들어둔 설정 사용)
import { coreApi } from '../api/axios';

function CardUpload() {
  const [selectedFile, setSelectedFile] = useState(null); // 선택된 파일
  const [uploading, setUploading] = useState(false); // 업로드 중 로딩 표시
  const [isDragOver, setIsDragOver] = useState(false); // 드래그 중인지 체크
  const fileInputRef = useRef(null); // 숨겨진 input 태그 연결용

  // 🌟 [수정됨] 양식 다운로드 (부서명 포함 총 7개 항목)
  const handleDownloadSample = () => {
    // 순서: 일시, 카드, 이름, 부서, 가맹점, 금액, 업종
    const csvContent = `승인일시,카드번호,사용자명,부서명,가맹점명,승인금액,업종`;
    // 한글 깨짐 방지용 BOM(\uFEFF) 추가
    const blob = new Blob(["\uFEFF" + csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = '법인카드_사용내역_양식.csv';
    link.click();
  };

  // 1. 파일 선택 시 실행
  const handleFileChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      setSelectedFile(file);
    }
  };

  // 2. 드래그 이벤트 핸들러
  const handleDragOver = (e) => {
    e.preventDefault();
    setIsDragOver(true);
  };

  const handleDragLeave = (e) => {
    e.preventDefault();
    setIsDragOver(false);
  };

  const handleDrop = (e) => {
    e.preventDefault();
    setIsDragOver(false);
    const files = e.dataTransfer.files;
    if (files && files.length > 0) {
      const file = files[0];
      if (file.name.endsWith('.csv') || file.name.endsWith('.xlsx')) {
        setSelectedFile(file);
      } else {
        alert("csv 또는 xlsx 파일만 업로드 가능합니다!");
      }
    }
  };

  // 업로드 버튼 클릭
  const handleUpload = async () => {
    if (!selectedFile) {
      alert("파일을 먼저 선택해주세요!");
      return;
    }

    const formData = new FormData();
    formData.append("file", selectedFile); 

    try {
      setUploading(true);
      // 백엔드: POST /transactions/upload
      const response = await coreApi.post('/transactions/upload', formData, {
        headers: { "Content-Type": "multipart/form-data" }, 
      });
      
      alert(`성공! ${response.data.message || '업로드가 완료되었습니다.'}`);
      setSelectedFile(null); 
    } catch (error) {
      console.error("업로드 실패:", error);
      alert("업로드에 실패했습니다. 파일 형식을 확인해주세요.");
    } finally {
      setUploading(false);
    }
  };

  return (
    <Box>
      <Typography variant="h4" gutterBottom fontWeight="bold">법인카드 사용내역 업로드</Typography>
      <Typography color="textSecondary" mb={3}>카드사에서 다운로드 받은 엑셀(CSV) 파일을 이곳에 업로드하세요.</Typography>

      {/* 숨겨진 Input */}
      <input 
        type="file" 
        accept=".csv, .xlsx" 
        style={{ display: 'none' }} 
        ref={fileInputRef} 
        onChange={handleFileChange} 
      />
      
      {/* 드래그 앤 드롭 구역 */}
      <Paper 
        sx={{ 
          p: 5, 
          border: isDragOver ? '3px dashed #1976d2' : '2px dashed #90caf9', 
          bgcolor: isDragOver ? '#e3f2fd' : '#f0f7ff', 
          textAlign: 'center', 
          mb: 4, 
          cursor: 'pointer',
          transition: 'all 0.2s ease'
        }}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
        onClick={() => fileInputRef.current.click()} 
      >
        {uploading ? (
          <CircularProgress />
        ) : (
          <>
            <CloudUploadIcon sx={{ fontSize: 60, color: isDragOver ? '#1565c0' : '#1976d2', mb: 2 }} />
            <Typography variant="h6" color="primary" gutterBottom>
              {selectedFile ? `선택됨: ${selectedFile.name}` : "파일을 이곳으로 드래그하거나 클릭하세요"}
            </Typography>
            <Typography variant="body2" color="textSecondary" mb={2}>
              지원 형식: .csv (최대 10MB)
            </Typography>
            <Button variant="contained" size="large" onClick={(e) => {
               e.stopPropagation(); 
               if(selectedFile) handleUpload(); 
               else fileInputRef.current.click(); 
            }}>
              {selectedFile ? "업로드 시작하기 " : "파일 선택하기"}
            </Button>
          </>
        )}
      </Paper>

      <Box display="flex" gap={4} alignItems="flex-start">
        {/* 양식 다운로드 */}
        <Box flex={1}>
          <Typography variant="h6" gutterBottom fontWeight="bold">📂 업로드 양식</Typography>
          <Typography variant="body2" color="textSecondary" mb={2}>빈 양식을 다운로드하여 내용을 채워주세요.</Typography>
          <Paper variant="outlined" sx={{ display: 'flex', alignItems: 'center', p: 2, bgcolor: '#fafafa' }}>
            <DescriptionIcon color="action" sx={{ mr: 2, fontSize: 30 }} />
            <Box mr={3} flexGrow={1}>
              <Typography fontWeight="bold">법인카드_사용내역_양식.csv</Typography>
              <Typography variant="caption" color="textSecondary">1KB • CSV 파일</Typography>
            </Box>
            <Button variant="outlined" startIcon={<FileDownloadIcon />} onClick={handleDownloadSample} size="small">다운로드</Button>
          </Paper>
        </Box>

        {/* 작성 가이드 (부서명 추가됨) */}
        <Box flex={1.5}>
          <Box display="flex" alignItems="center" mb={1}>
            <InfoIcon color="primary" sx={{ mr: 1, fontSize: 20 }} />
            <Typography variant="h6" fontWeight="bold">작성 가이드</Typography>
          </Box>
          <TableContainer component={Paper} variant="outlined">
            <Table size="small">
              <TableHead sx={{ bgcolor: '#eeeeee' }}>
                <TableRow>
                  <TableCell width="30%"><strong>항목</strong></TableCell>
                  <TableCell><strong>입력 형식 / 예시</strong></TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                <TableRow><TableCell component="th">승인일시</TableCell><TableCell>YYYY-MM-DD HH:mm</TableCell></TableRow>
                <TableRow><TableCell component="th">카드번호</TableCell><TableCell>하이픈(-) 포함 16자리</TableCell></TableRow>
                <TableRow><TableCell component="th">사용자명</TableCell><TableCell>이름 (예: 홍길동)</TableCell></TableRow>
                {/* 🌟 부서명 항목 추가 */}
                <TableRow><TableCell component="th">부서명</TableCell><TableCell>팀 이름 (예: 영업팀)</TableCell></TableRow>
                <TableRow><TableCell component="th">가맹점명</TableCell><TableCell>결제처 (예: 스타벅스)</TableCell></TableRow>
                <TableRow><TableCell component="th">승인금액</TableCell><TableCell>숫자만 (예: 15000)</TableCell></TableRow>
                <TableRow><TableCell component="th">업종</TableCell><TableCell>식음료, 유흥 등</TableCell></TableRow>
              </TableBody>
            </Table>
          </TableContainer>
        </Box>
      </Box>

      <Divider sx={{ my: 4 }} />
      <Box>
        <Alert severity="info">
          <strong>업로드 시 주의사항:</strong> <br/>
          - 암호가 걸린 엑셀 파일은 업로드할 수 없습니다.<br/>
          - 위 가이드에 맞지 않는 데이터는 업로드 실패할 수 있습니다.
        </Alert>
      </Box>
    </Box>
  );
}

export default CardUpload;
