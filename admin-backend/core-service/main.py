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
# 🌟 [수정] 한국 시간 계산을 위해 timedelta 추가
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

# 📡 [수정됨] 감사 로그 전송 (한국 시간 적용!)
def send_audit_log(actor: str, action: str, result: str, target: str):
    try:
        # 🌟 UTC 현재 시간에서 9시간을 더해 KST로 변환!
        kst_now = datetime.utcnow() + timedelta(hours=9)
        
        log_data = {
            "event_type": "TRANSACTION", 
            "actor_id": actor,
            "actor_type": "USER",
            "source_ip": "127.0.0.1",
            "action": action, 
            "result": result,
            "target_id": target,
            "target_type": "SYSTEM",
            # 🌟 DB 시간이 아니라, 여기서 계산한 한국 시간을 보냅니다!
            "event_time": kst_now.strftime("%Y-%m-%d %H:%M:%S")
        }
        requests.post("http://127.0.0.1:8002/logs", json=log_data, timeout=1)
    except Exception as e:
        print(f"⚠️ Audit Log 전송 실패: {e}")

def find_idx(headers, candidates):
    for name in candidates:
        if name in headers:
            return headers.index(name)
    return -1

# =========================================================
# 📊 [View 2] 재무팀 통계 조회 API (해빈님 원본 그대로!)
# =========================================================
@app.get("/stats")
def get_stats(db: Session = Depends(get_db)):
    # 1. 상단 카드용 전체 숫자
    total = db.query(models.CardTransaction).count()
    violation = db.query(models.ViolationResult).filter(models.ViolationResult.is_violation == True).count()

    # 🌟 오늘 기준 최근 7일 날짜 설정 (2026-01-12 기준)
    today = datetime(2026, 1, 12) 
    start_date = today - timedelta(days=6)

    # 2. 최근 7일간 위반 건수
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

    # 3. 부서별 위반 현황
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
# 🛠️ [View 1] 인프라 운영 콘솔 API (🔥 여기만 바꿨습니다!)
# =========================================================
@app.get("/dashboard/infra")
def get_infra_dashboard(db: Session = Depends(get_db)):
    # 1. Prometheus 상태 체크
    prom_status = "DOWN"
    try:
        if settings.PROMETHEUS_URL:
            requests.get(f"{settings.PROMETHEUS_URL}/-/healthy", timeout=1)
            prom_status = "UP"
    except: pass
    
    # 2. 진짜 DB 접속률 체크 (pg_stat_activity 사용)
    real_db_usage = 0
    db_conn_count = 0
    try:
        # 해빈님이 연결한 그 DB의 실제 세션 수를 가져옵니다!
        result = db.execute(text("SELECT count(*) FROM pg_stat_activity;"))
        db_conn_count = result.scalar()
        real_db_usage = int((db_conn_count / 100) * 100) # 100개 기준 퍼센트
    except Exception as e:
        print(f"⚠️ DB Check Error: {e}")

    # 🌟 3. [Real-Time Alert] 문제가 있을 때만 events 리스트에 추가!
    events = []
    current_time = datetime.now().strftime("%H:%M")

    # (조건 1) DB 사용량이 80%를 넘으면 경고!
    if real_db_usage >= 80:
        events.append({
            "time": current_time,
            "severity": "CRITICAL",
            "target": "DB-Connection",
            "message": f"🔥 과부하 경고: 세션 점유율 {real_db_usage}% 도달!"
        })

    # (조건 2) Prometheus가 죽어있으면 경고!
    if prom_status != "UP":
        events.append({
            "time": current_time,
            "severity": "WARNING",
            "target": "Monitoring",
            "message": "⚠️ Prometheus 서버 응답 없음"
        })

    # 상단 카드용 데이터 요약
    alert_summary = {"critical": 0, "warning": 0}
    if prom_status != "UP": alert_summary["warning"] += 1
    if real_db_usage >= 80: alert_summary["critical"] += 1

    return {
        "status_summary": {
            "alert": alert_summary,
            "eks": {"nodes_ready": 5, "pods_crash": 0},
            "vpn": {"status": "UP", "latency": "12ms"},
            "db": {
                "usage_percent": real_db_usage, # 👈 리얼 데이터
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
        "recent_events": events # 👈 평소엔 [], 문제 생기면 알람 뜸!
    }

# =========================================================
# 📤 파일 업로드 API (해빈님 원본 로직 100% 유지)
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
    # 🌟 해빈님이 작성한 변수명 그대로 유지!
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

            # 🌟 해빈님의 위반 판단 로직 유지
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

    send_audit_log(actor="admin", action="UPLOAD", result="SUCCESS", target="Card_CSV")
    
    return {"message": f"{processed_count}건 처리 완료"}

# =========================================================
# 🚨 위반 내역 조회 API (해빈님 원본 그대로!)
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