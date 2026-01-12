from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from fastapi.middleware.cors import CORSMiddleware
import os

# DB 연결 (audit_db)
DB_URL = "postgresql://postgres:123456@127.0.0.1:5432/audit_db"

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

# 🌟 [핵심] 성민님이 'SYSTEM'을 추가해주셨으니, 기본값을 'SYSTEM'으로 설정!
# 이제 빈칸으로 들어와도 에러 안 나고 'SYSTEM'으로 저장됩니다.
class LogRequest(BaseModel):
    event_type: str
    actor_id: str
    actor_type: str = "USER"
    source_ip: str
    action: str
    result: str
    target_id: str = None
    target_type: str = "SYSTEM"  # 🌟 SYSTEM 사용 (이제 에러 안 남!)

@app.post("/logs")
def create_log(log: LogRequest):
    try:
        with engine.connect() as conn:
            query = text("""
                INSERT INTO audit.audit_events 
                (event_type, actor_id, actor_type, source_ip, action, result, target_id, target_type)
                VALUES 
                (:event_type, :actor_id, :actor_type, :source_ip, :action, :result, :target_id, :target_type)
            """)
            
            conn.execute(query, {
                "event_type": log.event_type,
                "actor_id": log.actor_id,
                "actor_type": log.actor_type,
                "source_ip": log.source_ip,
                "action": log.action,
                "result": log.result,
                "target_id": log.target_id,
                "target_type": log.target_type 
            })
            conn.commit()
            
        print(f"✅ 로그 저장 성공: [{log.action}] {log.actor_id}")
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