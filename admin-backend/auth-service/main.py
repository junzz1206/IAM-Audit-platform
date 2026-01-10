from fastapi import FastAPI, HTTPException, Depends
from starlette.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from middleware import AuditLogMiddleware
from redis_client import save_login_session
from database import engine
from config import settings
import models
import uuid

#models.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    debug=settings.DEBUG
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(AuditLogMiddleware)

class LoginRequest(BaseModel):
    username: str
    password: str

@app.get("/")
def read_root():
    return {
        "system": "IAM Auth Service",
        "status": "Healthy"
    }

@app.post("/auth/login")
def login(req: LoginRequest):
    # 실제로는 DB(Credential)에서 비밀번호 해시를 검증해야 함
    # 여기서는 스켈레톤 코드이므로 하드코딩된 로직 유지
    if req.username == "finance" and req.password == "1234":
        token = str(uuid.uuid4())
        # Redis에 세션 저장 (1시간)
        save_login_session(req.username, token, 3600)
        return {
            "token": token,
            "role": "FINANCE",
            "message": "Login successful"
        }
    
    elif req.username == "infra" and req.password == "1234":
        token = str(uuid.uuid4())
        save_login_session(req.username, token, 3600)
        return {
            "token": token,
            "role": "INFRA",
            "message": "Login successful"
        }

    raise HTTPException(status_code=401, detail="Incorrect username or password")
