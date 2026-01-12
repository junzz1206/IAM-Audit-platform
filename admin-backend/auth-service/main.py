from fastapi import FastAPI, HTTPException, Request, Depends
from starlette.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy.orm import Session
from passlib.context import CryptContext
# 🌟 해빈님 코드의 Redis 기능 그대로 유지!
from redis_client import save_login_session
from database import engine, get_db
import models
import uuid
import requests
import json
# 🌟 [추가] 한국 시간(KST) 계산을 위한 도구
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

# 🌟 [추가] 로그아웃 요청용 모델
class LogoutRequest(BaseModel):
    username: str

# 📡 감사 로그 전송 함수 (한국 시간 적용!)
def send_audit_log(username: str, ip: str, action: str, result: str):
    try:
        # 🌟 1. 현재 UTC 시간에서 9시간을 더해 '한국 시간(KST)'을 만듭니다.
        kst_now = datetime.utcnow() + timedelta(hours=9)

        # 2. Action 및 Event Type 매핑
        safe_action = "EXECUTE" if action == "LOGIN_ATTEMPT" else action
        
        safe_event = "LOGIN"
        if action == "LOGOUT":
            safe_event = "LOGOUT" # 로그아웃이면 이벤트 타입도 변경

        log_data = {
            "event_type": safe_event, 
            "actor_id": username,
            "actor_type": "USER",
            "source_ip": ip,
            "action": safe_action,
            "result": result,
            "target_id": "System_Auth",
            "target_type": "SYSTEM",
            # 🌟 3. [핵심] 계산한 한국 시간을 DB로 같이 보냅니다! (이게 있어야 상단에 뜸)
            "event_time": kst_now.strftime("%Y-%m-%d %H:%M:%S")
        }
        
        # 4. 로그 서버로 전송 (혹시 실패해도 에러 안 나게 try-except 처리)
        requests.post("http://127.0.0.1:8002/logs", json=log_data, timeout=1)
        
        # 터미널에서 전송 확인용 출력
        print(f"🚀 [Log Sent] {safe_event} - {username} at {kst_now.strftime('%H:%M:%S')}")

    except Exception as e:
        print(f"⚠️ Audit Log 전송 실패: {e}")

@app.post("/auth/login")
def login(req: LoginRequest, request: Request, db: Session = Depends(get_db)):
    client_ip = request.client.host if request.client else "unknown"
    print(f"🔒 로그인 시도: {req.username}")

    try:
        # [Step 1] DB에서 유저 조회 (해빈님 코드 유지)
        user_data = (
            db.query(models.User, models.Credential, models.Role)
            .join(models.Credential, models.User.user_id == models.Credential.user_id)
            .join(models.UserRole, models.User.user_id == models.UserRole.user_id)
            .join(models.Role, models.UserRole.role_id == models.Role.role_id)
            .filter(models.User.username == req.username)
            .first()
        )

        if not user_data:
            # 실패 로그 (KST 시간 전송)
            send_audit_log(req.username, client_ip, "LOGIN_ATTEMPT", "FAILURE")
            raise HTTPException(status_code=401, detail="User not found")

        user, cred, role = user_data

        # [Step 2] 비밀번호 검증
        if not pwd_context.verify(req.password, cred.password_hash):
            # 실패 로그 (KST 시간 전송)
            send_audit_log(req.username, client_ip, "LOGIN_ATTEMPT", "FAILURE")
            raise HTTPException(status_code=401, detail="Incorrect password")

        # [Step 3] 로그인 성공 처리
        token = str(uuid.uuid4())
        
        # 🌟 해빈님의 Redis 세션 저장 로직 유지!
        save_login_session(user.user_id, token, role.role_name)
        
        # 성공 로그 (KST 시간 전송)
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

# 🌟 [추가] 로그아웃 API (이게 없어서 추가했어요!)
@app.post("/auth/logout")
def logout(req: LogoutRequest, request: Request):
    client_ip = request.client.host if request.client else "unknown"
    
    # 로그아웃 로그 전송 (KST 시간 적용)
    send_audit_log(req.username, client_ip, "LOGOUT", "SUCCESS")
    
    print(f"🚪 로그아웃: {req.username}")
    return {"message": "Logged out successfully"}