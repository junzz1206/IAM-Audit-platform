from fastapi import FastAPI
from starlette.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from middleware import AuditLogMiddleware
from database import engine, settings
import models
import datetime

# DB 연결 잠시 끄기
# models.Base.metadata.create_all(bind=engine)

app = FastAPI(title=settings.PROJECT_NAME, version=settings.VERSION)

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 미들웨어 추가
app.add_middleware(AuditLogMiddleware)

# 로그 데이터 구조 정의
class LogItem(BaseModel):
    service_name: str
    user_id: str = None
    ip_address: str
    action: str
    status: str
    severity: str
    details: str = None

@app.get("/")
def read_root():
    return {
        "system": "Audit Log Service",
        "status": "Healthy"
    }

# 로그 저장 API (기존 기능)
@app.post("/logs")
def create_log(log: LogItem):
    print(f"[LOG RECEIVED] {log.service_name}: {log.action} ({log.severity})")
    return {"message": "Log saved successfully"}

# [추가됨] 로그 조회 API (AuditLog.jsx용 - 가짜 데이터 추가!)
@app.get("/logs")
def get_audit_logs():
    return [
        {
            "log_id": "uuid-1",
            "timestamp": "2025-01-07 10:00:00",
            "service_name": "Auth Service",
            "user_id": "admin",
            "ip_address": "192.168.1.5",
            "action": "LOGIN_SUCCESS",
            "severity": "SUCCESS",
            "details": "관리자 로그인 성공"
        },
        {
            "log_id": "uuid-2",
            "timestamp": "2025-01-07 10:05:22",
            "service_name": "Core Service",
            "user_id": "unknown",
            "ip_address": "211.45.xx.xx",
            "action": "INVALID_ACCESS",
            "severity": "WARNING",
            "details": "허가되지 않은 접근 시도"
        },
        {
            "log_id": "uuid-3",
            "timestamp": "2025-01-07 11:30:00",
            "service_name": "Core Service",
            "user_id": "admin",
            "ip_address": "192.168.1.5",
            "action": "FILE_UPLOAD",
            "severity": "SUCCESS",
            "details": "법인카드_1월.csv 업로드 완료"
        },
        {
            "log_id": "uuid-4",
            "timestamp": "2025-01-07 12:00:00",
            "service_name": "Core Service",
            "user_id": "system",
            "ip_address": "localhost",
            "action": "RULE_ENGINE_CHECK",
            "severity": "INFO",
            "details": "정기 규정 위반 검사 완료"
        },
        {
            "log_id": "uuid-5",
            "timestamp": "2025-01-07 13:45:11",
            "service_name": "Auth Service",
            "user_id": "infra",
            "ip_address": "192.168.1.10",
            "action": "LOGIN_FAIL",
            "severity": "ERROR",
            "details": "비밀번호 5회 오류"
        }
    ]
