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

# 📡 감사 로그 전송 함수 (성민님 DB 규칙 완벽 적용!)
def send_audit_log(username: str, ip: str, action: str, result: str):
    try:
        # 1. Action 매핑 (목록에 없는 단어는 있는 단어로 교체)
        # LOGIN 시도는 'EXECUTE'(실행)으로 대체
        safe_action = "EXECUTE" if action == "LOGIN_ATTEMPT" else action
        
        # 2. Event Type 매핑
        # LOGIN은 목록에 있으므로 그대로 사용!
        safe_event = "LOGIN"

        log_data = {
            "event_type": safe_event, # 'LOGIN' (목록에 있음!)
            "actor_id": username,
            "actor_type": "USER",     # 빈칸 방지용 'USER'
            "source_ip": ip,
            "action": safe_action,    # 'EXECUTE' (목록에 있음!)
            "result": result,
            "target_id": "System_Auth"
        }
        requests.post("http://127.0.0.1:8002/logs", json=log_data, timeout=1)
    except Exception as e:
        print(f"⚠️ Audit Log 전송 실패: {e}")

@app.post("/auth/login")
def login(req: LoginRequest, request: Request, db: Session = Depends(get_db)):
    client_ip = request.client.host if request.client else "unknown"
    print(f"🔒 로그인 시도: {req.username}")

    try:
        # [Step 1] DB에서 유저 조회
        user_data = (
            db.query(models.User, models.Credential, models.Role)
            .join(models.Credential, models.User.user_id == models.Credential.user_id)
            .join(models.UserRole, models.User.user_id == models.UserRole.user_id)
            .join(models.Role, models.UserRole.role_id == models.Role.role_id)
            .filter(models.User.username == req.username)
            .first()
        )

        if not user_data:
            # 실패 시에도 로그 전송
            send_audit_log(req.username, client_ip, "LOGIN_ATTEMPT", "FAILURE")
            raise HTTPException(status_code=401, detail="User not found")

        user, cred, role = user_data

        # [Step 2] 비밀번호 검증
        if not pwd_context.verify(req.password, cred.password_hash):
            send_audit_log(req.username, client_ip, "LOGIN_ATTEMPT", "FAILURE")
            raise HTTPException(status_code=401, detail="Incorrect password")

        # [Step 3] 로그인 성공 처리
        token = str(uuid.uuid4())
        save_login_session(user.user_id, token, role.role_name)
        
        # 성공 로그 전송
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