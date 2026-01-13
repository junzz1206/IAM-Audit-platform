from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from fastapi.middleware.cors import CORSMiddleware
import os
from datetime import datetime
from typing import Optional

# ---------------------------------------------------------
# 🌟 [수정] 하드코딩 삭제하고 환경변수 우선으로 변경!
# ---------------------------------------------------------
# 1순위: docker-compose.yml이 주는 주소 (DATABASE_URL)
# 2순위: 없으면 윈도우 도커용 주소 (host.docker.internal)
DEFAULT_URL = "postgresql://postgres:123456@host.docker.internal:5432/audit_db"
DB_URL = os.getenv("DATABASE_URL", DEFAULT_URL)

print(f"🔥 [Audit Main] DB 연결 시도: {DB_URL}")
# ---------------------------------------------------------

engine = create_engine(DB_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

app = FastAPI(title="Audit Log Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class LogRequest(BaseModel):
    event_type: str
    actor_id: str
    actor_type: str = "USER"
    source_ip: str
    action: str
    result: str
    target_id: Optional[str] = None
    target_type: str = "SYSTEM"
    event_time: Optional[str] = None 

@app.post("/logs")
def create_log(log: LogRequest):
    try:
        final_time = log.event_time if log.event_time else str(datetime.now())

        with engine.connect() as conn:
            query = text("""
                INSERT INTO audit.audit_events 
                (event_type, actor_id, actor_type, source_ip, action, result, target_id, target_type, created_at)
                VALUES 
                (:event_type, :actor_id, :actor_type, :source_ip, :action, :result, :target_id, :target_type, :created_at)
            """)
            
            conn.execute(query, {
                "event_type": log.event_type,
                "actor_id": log.actor_id,
                "actor_type": log.actor_type,
                "source_ip": log.source_ip,
                "action": log.action,
                "result": log.result,
                "target_id": log.target_id,
                "target_type": log.target_type,
                "created_at": final_time
            })
            conn.commit()
            
        print(f"✅ 로그 저장 성공: [{log.action}] {log.actor_id} (Time: {final_time})")
        return {"status": "success"}
        
    except Exception as e:
        print(f"❌ 로그 저장 실패 (DB연결/쿼리오류): {e}")
        return {"status": "error", "message": str(e)}

@app.get("/logs")
def read_logs():
    try:
        with engine.connect() as conn:
            result = conn.execute(text("""
                SELECT event_type, actor_id, source_ip, action, result, target_id, target_type, created_at 
                FROM audit.audit_events 
                ORDER BY created_at DESC
            """))
            logs = []
            for row in result:
                logs.append({
                    "event_type": row.event_type,
                    "actor_id": row.actor_id,
                    "source_ip": row.source_ip,
                    "action": row.action,
                    "result": row.result,
                    "target_id": row.target_id,
                    "created_at": str(row.created_at)
                })
        return logs
    except Exception as e:
        print(f"❌ 로그 조회 실패: {e}")
        return []