from fastapi import FastAPI, HTTPException, Request, Depends
from starlette.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy.orm import Session
from passlib.context import CryptContext
from redis_client import save_login_session
from database import engine, get_db
import models
import uuid
import requests
import json
import os # 🌟 [필수 추가] 환경변수 쓰려면 이거 있어야 해요!
from datetime import datetime, timedelta

# DB 스키마 생성
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="IAM Auth Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_credentials=True, 
    allow_methods=["*"], allow_headers=["*"]
)

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

class LoginRequest(BaseModel):
    username: str
    password: str

class LogoutRequest(BaseModel):
    username: str

# 📡 감사 로그 전송 함수
def send_audit_log(username: str, ip: str, action: str, result: str):
    try:
        # 1. 한국 시간(KST) 계산
        kst_now = datetime.utcnow() + timedelta(hours=9)

        # 2. Action 매핑
        safe_action = "EXECUTE" if action == "LOGIN_ATTEMPT" else action
        safe_event = "LOGOUT" if action == "LOGOUT" else "LOGIN"

        log_data = {
            "event_type": safe_event, 
            "actor_id": username,
            "actor_type": "USER",
            "source_ip": ip,
            "action": safe_action,
            "result": result,
            "target_id": "System_Auth",
            "target_type": "SYSTEM",
            "event_time": kst_now.strftime("%Y-%m-%d %H:%M:%S")
        }
        
        # -------------------------------------------------------------
        # 🌟 [수정] 여기가 핵심입니다!!
        # 127.0.0.1은 도커 안에서 '나 자신'이라서 에러 납니다.
        # docker-compose.yml에서 넘겨준 주소(http://audit-service:8000)를 씁니다.
        # -------------------------------------------------------------
        audit_url = os.getenv("AUDIT_SERVICE_URL", "http://audit-service:8000")
        
        # 주소 뒤에 /logs 붙여서 전송
        requests.post(f"{audit_url}/logs", json=log_data, timeout=1)
        
        print(f"🚀 [Log Sent] {safe_event} - {username} at {kst_now.strftime('%H:%M:%S')}")

    except Exception as e:
        print(f"⚠️ Audit Log 전송 실패: {e}")

@app.post("/auth/login")
def login(req: LoginRequest, request: Request, db: Session = Depends(get_db)):
    client_ip = request.client.host if request.client else "unknown"
    print(f"🔒 로그인 시도: {req.username}")

    try:
        # [Step 1] 유저 조회
        user_data = (
            db.query(models.User, models.Credential, models.Role)
            .join(models.Credential, models.User.user_id == models.Credential.user_id)
            .join(models.UserRole, models.User.user_id == models.UserRole.user_id)
            .join(models.Role, models.UserRole.role_id == models.Role.role_id)
            .filter(models.User.username == req.username)
            .first()
        )

        if not user_data:
            send_audit_log(req.username, client_ip, "LOGIN_ATTEMPT", "FAILURE")
            raise HTTPException(status_code=401, detail="User not found")

        user, cred, role = user_data

        # [Step 2] 비밀번호 검증
        if not pwd_context.verify(req.password, cred.password_hash):
            send_audit_log(req.username, client_ip, "LOGIN_ATTEMPT", "FAILURE")
            raise HTTPException(status_code=401, detail="Incorrect password")

        # [Step 3] 로그인 성공
        token = str(uuid.uuid4())
        save_login_session(user.user_id, token, role.role_name)
        send_audit_log(req.username, client_ip, "LOGIN_ATTEMPT", "SUCCESS")

        print(f"✅ 로그인 최종 성공: {user.username}")

        return {
            "token": token,
            "role": role.role_name,
            "username": user.username,
            "message": "Login successful"
        }

    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"🔥 시스템 에러: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/auth/logout")
def logout(req: LogoutRequest, request: Request):
    client_ip = request.client.host if request.client else "unknown"
    send_audit_log(req.username, client_ip, "LOGOUT", "SUCCESS")
    print(f"🚪 로그아웃: {req.username}")
    return {"message": "Logged out successfully"}