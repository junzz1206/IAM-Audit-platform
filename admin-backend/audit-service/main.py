from fastapi import FastAPI, Depends, HTTPException
from starlette.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import text # SQL 쿼리 날리기 위해 필요
from middleware import AuditLogMiddleware
from database import engine, settings, get_db
import models

# DB 테이블 생성
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title=settings.PROJECT_NAME, version=settings.VERSION)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(AuditLogMiddleware)

class LogItem(BaseModel):
    event_type: str
    actor_id: str
    source_ip: str
    action: str
    result: str
    target_id: str = None

@app.get("/")
def read_root():
    return {"system": "Audit Log Service", "status": "Healthy"}

# ---------------------------------------------------------
# ✅ [수정] 인프라 대시보드 (DB 상태 100% 리얼 데이터 적용!)
# ---------------------------------------------------------
@app.get("/dashboard/infra")
def get_infra_dashboard(db: Session = Depends(get_db)):
    # 1. DB 상태 실시간 측정 (SQL 쿼리 사용)
    db_usage_percent = 0
    db_blocked = False
    
    try:
        # (1) 최대 접속 가능 수 (max_connections) 조회
        # SQL: postgres 설정에서 max_connections 값을 가져와라
        result = db.execute(text("SELECT setting::int FROM pg_settings WHERE name = 'max_connections'"))
        max_conn = result.scalar()

        # (2) 현재 접속 중인 세션 수 (active connections) 조회
        # SQL: pg_stat_activity 테이블에서 현재 접속자 수를 세어라
        result = db.execute(text("SELECT count(*) FROM pg_stat_activity"))
        current_conn = result.scalar()

        # (3) 사용률 계산 (%)
        if max_conn > 0:
            db_usage_percent = round((current_conn / max_conn) * 100)

        # (4) 차단된(Blocked) 세션 있는지 확인
        # SQL: 'Lock' 때문에 기다리고 있는(wait_event_type='Lock') 애들이 있는지 확인
        result = db.execute(text("SELECT count(*) FROM pg_stat_activity WHERE wait_event_type = 'Lock'"))
        blocked_count = result.scalar()
        
        # 0명보다 많으면 Blocked 상태(True)
        db_blocked = blocked_count > 0

    except Exception as e:
        print(f"DB Stat Error: {e}")
        # 에러 나면 0으로 표시 (연결 실패로 간주될 수 있음)

    # 2. 최근 로그 가져오기 (이건 기존과 동일)
    recent_logs = []
    try:
        logs = db.query(models.AuditEvent).order_by(models.AuditEvent.created_at.desc()).limit(5).all()
        for log in logs:
            recent_logs.append({
                "time": log.created_at.strftime("%H:%M"),
                "severity": "CRITICAL" if log.result == "FAILURE" else "INFO",
                "target": log.target_id or "System",
                "message": f"{log.action} - {log.result}"
            })
    except:
        pass

    # 3. 데이터 반환
    return {
        "status_summary": {
            "alert": {"critical": 0, "warning": 0},
            "eks": {"nodes_ready": 0, "pods_crash": 0},
            "vpn": {"status": "DOWN", "latency": "-"},
            
            # ✅ 여기가 진짜 DB 상태! (계산된 퍼센트와 Blocked 여부)
            "db": {
                "usage_percent": db_usage_percent, 
                "blocked": db_blocked
            }
        },
        "recent_events": recent_logs,
        "quick_links": {
            "grafana_cluster": "#", 
            "grafana_db": "#", 
            "hubble": "#", 
            "loki": "#", 
            "argocd": "#", 
            "runbook": "#"
        }
    }

# --- (아래 통계, 로그 조회 API는 그대로 유지) ---
@app.get("/dashboard/stats")
def get_finance_stats(db: Session = Depends(get_db)):
    try:
        tx_count = db.query(models.CardTransaction).count()
        violation_count = db.query(models.ViolationResult).count()
        return {
            "total_transactions": tx_count,
            "violation_count": violation_count,
            "system_status": "NORMAL",
            "daily_violations": [],
            "department_stats": []
        }
    except:
        return {"total_transactions": 0, "violation_count": 0, "system_status": "DB_ERROR"}

@app.get("/audit-logs")
def get_audit_logs(db: Session = Depends(get_db)):
    logs = db.query(models.AuditEvent).order_by(models.AuditEvent.created_at.desc()).limit(100).all()
    result = []
    for log in logs:
        result.append({
            "audit_id": str(log.audit_id),
            "created_at": log.created_at,
            "event_type": log.event_type,
            "actor_id": log.actor_id,
            "source_ip": log.source_ip,
            "action": log.action,
            "target_id": log.target_id,
            "result": log.result
        })
    return result

@app.post("/logs")
def create_log(log: LogItem, db: Session = Depends(get_db)):
    new_log = models.AuditEvent(
        event_type=log.event_type,
        actor_id=log.actor_id,
        source_ip=log.source_ip,
        action=log.action,
        result=log.result,
        target_id=log.target_id
    )
    db.add(new_log)
    db.commit()
    return {"message": "Log saved"}
