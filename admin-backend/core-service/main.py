from fastapi import FastAPI, Depends, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
import models
from database import engine, get_db
import csv
import io
import requests
from datetime import datetime
import uuid
from sqlalchemy import func, and_
from datetime import datetime, timedelta

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
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 📡 감사 로그 전송
def send_audit_log(actor: str, action: str, result: str, target: str):
    try:
        log_data = {
            "event_type": "TRANSACTION", 
            "actor_id": actor,
            "actor_type": "USER",
            "source_ip": "127.0.0.1",
            "action": action, 
            "result": result,
            "target_id": target,
            "target_type": "SYSTEM"
        }
        requests.post("http://127.0.0.1:8002/logs", json=log_data, timeout=1)
    except Exception as e:
        print(f"⚠️ Audit Log 전송 실패: {e}")

def find_idx(headers, candidates):
    for name in candidates:
        if name in headers:
            return headers.index(name)
    return -1

# 📊 1. 통계 조회 API
@app.get("/stats")
def get_stats(db: Session = Depends(get_db)):
    # 1. 상단 카드용 전체 숫자
    total = db.query(models.CardTransaction).count()
    violation = db.query(models.ViolationResult).filter(models.ViolationResult.is_violation == True).count()

    # 🌟 오늘 기준 최근 7일 날짜 설정 (2026-01-12 기준)
    today = datetime(2026, 1, 12) # 시연 날짜 고정 또는 datetime.now()
    start_date = today - timedelta(days=6)

    # 2. 최근 7일간 위반 건수 (진짜 DB 데이터 집계)
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
            models.CardTransaction.tx_date <= today + timedelta(days=1) # 13일 데이터까지 포함
        )
    ).group_by('day').order_by('day').all()

    # 3. 부서별 위반 현황 (진짜 DB 데이터 집계)
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

# 📤 2. 파일 업로드 API
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
            
            # ID 변환 (문자열 -> UUID 객체)
            raw_tx_id = get_val(idx_tx_id)
            final_tx_id = uuid.UUID(raw_tx_id) if raw_tx_id else uuid.uuid4()
            
            # 날짜/시간 처리
            raw_date = get_val(idx_date)
            is_late_night = False
            try:
                dt = datetime.strptime(raw_date, "%Y-%m-%d %H:%M")
                if dt.hour >= 22 or dt.hour < 6: is_late_night = True
                tx_datetime = dt
            except: tx_datetime = datetime.now()

            # 금액 처리
            amount_val = float(str(get_val(idx_amount)).replace(",", ""))

            # 위반 체크
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

            # DB 저장
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
    return {"message": f"{processed_count}건 처리 완료"}

# 🚨 3. [중요] 위반 내역 조회 API (404 방지)
@app.get("/violations")
def get_violations(db: Session = Depends(get_db)):
    # 🌟 .filter(...) 부분을 삭제하면 '전체' 데이터를 가져옵니다!
    results = db.query(
        models.ViolationResult,
        models.CardTransaction
    ).join(
        models.CardTransaction, 
        models.ViolationResult.tx_id == models.CardTransaction.tx_id
    ).all() # 👈 filter를 지웠어요!

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
            "is_violation": v.is_violation # 🌟 프론트에서 필터링할 때 필요해요!
        } for v, ct in results
    ]