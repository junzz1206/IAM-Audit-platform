from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from fastapi.middleware.cors import CORSMiddleware
import os
# 🌟 [추가] 시간이 없을 때를 대비해 datetime 추가
from datetime import datetime
from typing import Optional

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

# 🌟 [수정] event_time 필드 추가 (이게 있어야 422 에러가 안 나요!)
class LogRequest(BaseModel):
    event_type: str
    actor_id: str
    actor_type: str = "USER"
    source_ip: str
    action: str
    result: str
    target_id: str = None
    target_type: str = "SYSTEM"
    # 👇 보내준 시간이 있으면 받고, 없으면 None
    event_time: Optional[str] = None 

@app.post("/logs")
def create_log(log: LogRequest):
    try:
        # 🌟 [로직 추가] 받은 시간이 있으면 그걸 쓰고, 없으면 현재 시간
        final_time = log.event_time if log.event_time else str(datetime.now())

        with engine.connect() as conn:
            # 🌟 [쿼리 수정] created_at 컬럼을 명시적으로 추가!
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
                # 👇 우리가 정한 시간(KST)을 넣습니다!
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