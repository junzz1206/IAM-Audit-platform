from fastapi import FastAPI, Depends, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, text
import models
from database import engine, get_db
import csv
import io
import requests
import uuid
import os  # 🌟 [필수 추가] 환경변수 쓰려면 필요!
from datetime import datetime, timedelta 
from config import settings

# DB 테이블 생성
try:
    models.Base.metadata.create_all(bind=engine)
    print("✅ [Main] DB 테이블 준비 완료")
except Exception as e:
    print(f"⚠️ [Main] DB 연결 확인 필요: {e}")

app = FastAPI()

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS, 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 📡 [수정됨] 감사 로그 전송 함수
def send_audit_log(actor: str, action: str, result: str, target: str):
    try:
        # 1. 한국 시간(KST) 변환
        kst_now = datetime.utcnow() + timedelta(hours=9)
        
        log_data = {
            "event_type": "TRANSACTION", 
            "actor_id": actor,
            "actor_type": "USER",
            "source_ip": "CORE_SYSTEM", # 내부 시스템이라 고정
            "action": action, 
            "result": result,
            "target_id": target,
            "target_type": "SYSTEM",
            "event_time": kst_now.strftime("%Y-%m-%d %H:%M:%S")
        }
        
        # ---------------------------------------------------------
        # 🌟 [수정] 여기가 핵심! 127.0.0.1 삭제 -> 환경변수 사용
        # docker-compose.yml이 주는 'http://audit-service:8000'을 씁니다.
        # ---------------------------------------------------------
        audit_url = os.getenv("AUDIT_SERVICE_URL", "http://audit-service:8000")
        
        requests.post(f"{audit_url}/logs", json=log_data, timeout=1)
        
        # 전송 확인 로그
        print(f"🚀 [Log Sent] {action} - {actor}")

    except Exception as e:
        print(f"⚠️ Audit Log 전송 실패: {e}")

def find_idx(headers, candidates):
    for name in candidates:
        if name in headers:
            return headers.index(name)
    return -1

# =========================================================
# 📊 [View 2] 재무팀 통계 조회 API
# =========================================================
@app.get("/stats")
def get_stats(db: Session = Depends(get_db)):
    total = db.query(models.CardTransaction).count()
    violation = db.query(models.ViolationResult).filter(models.ViolationResult.is_violation == True).count()

    today = datetime.now() 
    start_date = today - timedelta(days=6)

    daily_res = db.query(
        func.to_char(models.CardTransaction.tx_date, 'MM/DD').label('day'),
        func.count(models.ViolationResult.violation_id).label('count')
    ).join(
        models.ViolationResult, 
        models.CardTransaction.tx_id == models.ViolationResult.tx_id
    ).filter(
        and_(
            models.ViolationResult.is_violation == True,
            models.CardTransaction.tx_date >= start_date,
            models.CardTransaction.tx_date <= today + timedelta(days=1)
        )
    ).group_by('day').order_by('day').all()

    dept_res = db.query(
        models.CardTransaction.department.label('name'),
        func.count(models.ViolationResult.violation_id).label('value')
    ).join(
        models.ViolationResult, 
        models.CardTransaction.tx_id == models.ViolationResult.tx_id
    ).filter(
        models.ViolationResult.is_violation == True
    ).group_by(models.CardTransaction.department).all()

    return {
        "total": total,
        "violation": violation,
        "status": "ok",
        "daily_violations": [{"day": r.day, "count": r.count} for r in daily_res],
        "department_stats": [{"name": r.name, "value": r.value} for r in dept_res]
    }

# =========================================================
# 🛠️ [View 1] 인프라 운영 콘솔 API
# =========================================================
@app.get("/dashboard/infra")
def get_infra_dashboard(db: Session = Depends(get_db)):
    prom_status = "DOWN"
    try:
        if settings.PROMETHEUS_URL:
            requests.get(f"{settings.PROMETHEUS_URL}/-/healthy", timeout=1)
            prom_status = "UP"
    except: pass
    
    real_db_usage = 0
    try:
        result = db.execute(text("SELECT count(*) FROM pg_stat_activity;"))
        db_conn_count = result.scalar()
        real_db_usage = int((db_conn_count / 100) * 100)
    except Exception as e:
        print(f"⚠️ DB Check Error: {e}")

    events = []
    current_time = datetime.now().strftime("%H:%M")

    if real_db_usage >= 80:
        events.append({
            "time": current_time,
            "severity": "CRITICAL",
            "target": "DB-Connection",
            "message": f"🔥 과부하 경고: 세션 점유율 {real_db_usage}% 도달!"
        })

    if prom_status != "UP":
        events.append({
            "time": current_time,
            "severity": "WARNING",
            "target": "Monitoring",
            "message": "⚠️ Prometheus 서버 응답 없음"
        })

    alert_summary = {"critical": 0, "warning": 0}
    if prom_status != "UP": alert_summary["warning"] += 1
    if real_db_usage >= 80: alert_summary["critical"] += 1

    return {
        "status_summary": {
            "alert": alert_summary,
            "eks": {"nodes_ready": 5, "pods_crash": 0},
            "vpn": {"status": "UP", "latency": "12ms"},
            "db": {
                "usage_percent": real_db_usage, 
                "blocked": False, 
                "host": settings.REAL_DB_HOST 
            }
        },
        "quick_links": {
            "grafana_cluster": settings.LINK_GRAFANA_CLUSTER,
            "grafana_db": settings.LINK_GRAFANA_DB,
            "hubble": settings.LINK_HUBBLE,
            "loki": settings.LINK_LOKI,
            "argocd": settings.LINK_ARGOCD,
            "runbook": settings.LINK_RUNBOOK
        },
        "recent_events": events
    }

# =========================================================
# 📤 파일 업로드 API
# =========================================================
@app.post("/transactions/upload")
async def upload_transactions(file: UploadFile = File(...), db: Session = Depends(get_db)):
    content = await file.read()
    
    try:
        decoded = content.decode('utf-8-sig')
    except UnicodeDecodeError:
        try:
            decoded = content.decode('cp949')
        except UnicodeDecodeError:
            raise HTTPException(status_code=400, detail="인코딩 오류")

    csv_reader = csv.reader(io.StringIO(decoded))
    rows = list(csv_reader)
    if not rows: return {"message": "파일이 비어있습니다."}

    headers = [h.strip().lower().replace(" ", "") for h in rows[0]]
    idx_tx_id = find_idx(headers, ["거래번호", "tx_id", "id"])
    idx_date = find_idx(headers, ["승인일시", "tx_date", "날짜"])
    idx_merchant = find_idx(headers, ["가맹점명", "merchant", "가맹점"])
    idx_amount = find_idx(headers, ["승인금액", "amount", "금액"])
    idx_card = find_idx(headers, ["카드번호", "card_id"])
    idx_user = find_idx(headers, ["사용자명", "이름"])
    idx_dept = find_idx(headers, ["부서명", "department"])
    idx_category = find_idx(headers, ["업종", "category"])
    
    processed_count = 0
    for i, row in enumerate(rows[1:], start=2):
        if not row: continue
        try:
            def get_val(idx): return row[idx] if idx != -1 and idx < len(row) else ""
            
            raw_tx_id = get_val(idx_tx_id)
            final_tx_id = uuid.UUID(raw_tx_id) if raw_tx_id else uuid.uuid4()
            
            raw_date = get_val(idx_date)
            is_late_night = False
            try:
                dt = datetime.strptime(raw_date, "%Y-%m-%d %H:%M")
                if dt.hour >= 22 or dt.hour < 6: is_late_night = True
                tx_datetime = dt
            except: tx_datetime = datetime.now()

            amount_val = float(str(get_val(idx_amount)).replace(",", ""))

            is_violation = False
            reason_txt = ""
            severity_val = 1
            merchant_val = get_val(idx_merchant)

            if amount_val >= 500000:
                is_violation, severity_val = True, 2
                reason_txt = "고액 결제(50만원 이상)"
            
            forbidden = ["유흥", "단란", "노래방", "PC방", "골프", "카지노", "야호", "클럽"]
            if any(k in merchant_val for k in forbidden):
                is_violation, severity_val = True, 3
                reason_txt = f"제한 업종({merchant_val})"

            if is_late_night:
                is_violation, severity_val = True, 2
                reason_txt += (", " if reason_txt else "") + "심야 시간 사용"

            db.add(models.CardTransaction(
                tx_id=final_tx_id, 
                card_id=get_val(idx_card), 
                user_name=get_val(idx_user),
                department=get_val(idx_dept),
                merchant_name=get_val(idx_merchant), 
                category=get_val(idx_category),
                merchant=merchant_val,
                amount=amount_val, 
                currency="KRW", 
                tx_date=tx_datetime,
                raw_payload={"department": get_val(idx_dept), "user_name": get_val(idx_user)}
            ))
            db.add(models.ViolationResult(
                tx_id=final_tx_id, rule_id=1, status="FAIL" if is_violation else "PASS",
                reason=reason_txt, is_violation=is_violation, severity=severity_val
            ))
            processed_count += 1
        except Exception as e:
            print(f"Row {i} Error: {e}")

    db.commit()

    # 파일 업로드 성공 로그 전송
    send_audit_log(actor="admin", action="UPLOAD", result="SUCCESS", target="Card_CSV")
    
    return {"message": f"{processed_count}건 처리 완료"}

# =========================================================
# 🚨 위반 내역 조회 API
# =========================================================
@app.get("/violations")
def get_violations(db: Session = Depends(get_db)):
    results = db.query(
        models.ViolationResult,
        models.CardTransaction
    ).join(
        models.CardTransaction, 
        models.ViolationResult.tx_id == models.CardTransaction.tx_id
    ).all()

    return [
        {
            "tx_date": ct.tx_date,
            "user_name": ct.user_name,
            "department": ct.department,
            "card_id": ct.card_id,
            "merchant_name": ct.merchant_name,
            "category": ct.category,
            "amount": ct.amount,
            "status": v.status,
            "reason": v.reason,
            "severity": v.severity,
            "is_violation": v.is_violation
        } for v, ct in results
    ]