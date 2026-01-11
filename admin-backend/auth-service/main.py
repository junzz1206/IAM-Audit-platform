from fastapi import FastAPI, HTTPException, Request, Depends
from starlette.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy.orm import Session
from passlib.context import CryptContext
from middleware import AuditLogMiddleware
from redis_client import save_login_session
from database import engine, get_db
import models
import uuid
import requests

# ---------------------------------------------------------
# [IAM Auth Service - Final Production Version]
# ---------------------------------------------------------
app = FastAPI(title="IAM Auth Service", version="1.0.0")

# 1. CORS 보안 설정
app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_credentials=True, 
    allow_methods=["*"], allow_headers=["*"]
)
app.add_middleware(AuditLogMiddleware)

# 2. 비밀번호 암호화 도구 (Bcrypt 알고리즘 사용)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

class LoginRequest(BaseModel):
    username: str
    password: str

# 감사 로그 전송 (Audit Service 연동)
def send_audit_log(username: str, ip: str, action: str, result: str):
    try:
        requests.post("http://127.0.0.1:8002/logs", json={
            "event_type": "LOGIN", "actor_id": username, "source_ip": ip,
            "action": action, "result": result, "target_id": "System_Auth"
        }, timeout=2)
    except: pass

@app.post("/auth/login")
def login(req: LoginRequest, request: Request, db: Session = Depends(get_db)):
    client_ip = request.client.host if request.client else "unknown"
    print(f"🔒 로그인 보안 검증 시작: {req.username}")

    try:
        # [Step 1] DB에서 사용자 정보 조회
        user_data = (
            db.query(
                models.User.username, 
                models.Credential.password_hash, 
                models.Role.role_name
            )
            .join(models.Credential, models.User.user_id == models.Credential.user_id)
            .join(models.UserRole, models.User.user_id == models.UserRole.user_id)
            .join(models.Role, models.UserRole.role_id == models.Role.role_id)
            .filter(models.User.username == req.username)
            .first()
        )

        if not user_data:
            print(f"❌ 계정 없음: {req.username}")
            raise HTTPException(status_code=401, detail="User not found")

        # [Step 2] 비밀번호 검증 (정석 로직)
        # 사용자가 입력한 비번을 암호화해서, DB에 있는 암호문과 비교
        password_valid = False
        
        try:
            # 1. 암호화된 비밀번호 비교 (Standard Way)
            if pwd_context.verify(req.password, user_data.password_hash):
                password_valid = True
        except Exception:
            # 2. (방어 코드) 혹시 DB에 평문이 들어있을 경우 대비
            if req.password == user_data.password_hash:
                password_valid = True

        # [Step 3] 검증 결과 처리
        if not password_valid:
            print(f"❌ 비밀번호 불일치 - 접근 거부")
            send_audit_log(req.username, client_ip, "LOGIN_ATTEMPT", "FAILURE")
            raise HTTPException(status_code=401, detail="Incorrect password")

        # [Step 4] 로그인 성공 & 토큰 발급
        print(f"✅ 인증 성공! 토큰 발급 중...")
        token = str(uuid.uuid4())
        save_login_session(user_data.username, token, 3600) # Redis 세션 저장
        send_audit_log(user_data.username, client_ip, "LOGIN_ATTEMPT", "SUCCESS")

        # 부서명 매핑 (프론트엔드 표시용)
        dept_name = "미지정 부서"
        if user_data.role_name == "FINANCE":
            dept_name = "재무회계팀"
        elif user_data.role_name == "INFRA":
            dept_name = "클라우드운영팀"

        return {
            "token": token,
            "role": user_data.role_name,
            "department": dept_name,
            "message": "Login successful"
        }
        
    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"🔥 시스템 에러: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")
