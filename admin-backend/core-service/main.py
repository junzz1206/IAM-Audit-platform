from fastapi import FastAPI, UploadFile, File, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import func, create_engine, text
import requests
import socket
import time
from kubernetes import client, config as k8s_config

# 점(.) 없는 import (같은 폴더에 있는 파일들)
from database import get_db, engine
from middleware import AuditLogMiddleware
from config import settings
import models
import io
import csv
import uuid
from datetime import datetime

# DB 테이블 생성 (서버 켜질 때 자동 생성)
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title=settings.PROJECT_NAME, version=settings.VERSION)

# CORS 설정 (프론트엔드와 통신하기 위해 필수)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 감사 로그 미들웨어 (누가 무슨 API 썼는지 기록)
app.add_middleware(AuditLogMiddleware)

# ---------------------------------------------------------
# 🛠️ [Helper] 진짜 인프라 상태 체크 함수들 (Real Logic)
# ---------------------------------------------------------

def check_vpn_latency(host: str, port: int = 51820, timeout=2):
    """VPN 게이트웨이 연결 상태 및 지연 시간 측정"""
    try:
        start_time = time.time()
        # 실제 소켓 연결 시도 (TCP)
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((host, port))
        sock.close()
        
        end_time = time.time()
        latency_ms = (end_time - start_time) * 1000 
        
        if result == 0:
            return {"status": "UP", "latency": f"{int(latency_ms)}ms"}
        else:
            return None # 연결 불가 (포트 닫힘)
    except:
        return None # 타임아웃 등 에러

def get_real_db_status():
    """온프레미스 PostgreSQL에 진짜로 접속해서 상태 조회"""
    try:
        # 실제 DB 연결 문자열 생성
        db_url = f"postgresql://{settings.REAL_DB_USER}:{settings.REAL_DB_PASSWORD}@{settings.REAL_DB_HOST}:{settings.REAL_DB_PORT}/{settings.REAL_DB_NAME}"
        monitor_engine = create_engine(db_url, connect_args={'connect_timeout': 2})
        
        with monitor_engine.connect() as connection:
            # 1. 활성 세션 수
            result_total = connection.execute(text("SELECT count(*) FROM pg_stat_activity;"))
            total_sessions = result_total.scalar()
            
            # 2. Lock 걸린 세션 수
            result_blocked = connection.execute(text("SELECT count(*) FROM pg_stat_activity WHERE wait_event_type = 'Lock';"))
            blocked_count = result_blocked.scalar()
            
            max_connections = 100 # 기준값
            usage_percent = int((total_sessions / max_connections) * 100)
            
            return {
                "usage_percent": usage_percent, 
                "blocked": True if blocked_count > 0 else False,
                "blocked_count": blocked_count
            }
    except Exception as e:
        # 🚨 에러 메시지를 터미널에 출력하게 만듦!
        print(f"\n========================================")
        print(f"🚨 [DB 연결 실패] 이유: {e}")
        print(f"========================================\n")
        return None

def get_real_k8s_status():
    """K8s API: 노드 상태 조회"""
    try:
        # K8s 설정 로드 시도 (로컬 or 클러스터 내부)
        try:
            k8s_config.load_kube_config() 
        except:
            k8s_config.load_incluster_config()
            
        v1 = client.CoreV1Api()
        nodes = v1.list_node().items
        
        ready_count = 0
        for node in nodes:
            for condition in node.status.conditions:
                if condition.type == "Ready" and condition.status == "True":
                    ready_count += 1
                    break
        return {"nodes_ready": ready_count, "nodes_total": len(nodes), "pods_crash": 0}
    except:
        # 설정 파일이 없거나 연결 안 되면 None 리턴
        return None

def get_real_prometheus_alert():
    """Prometheus API: 알람 조회"""
    try:
        # 실제 프로메테우스 호출 시도
        url = f"{settings.PROMETHEUS_URL}/api/v1/alerts"
        response = requests.get(url, timeout=2)
        data = response.json()
        
        if data["status"] == "success":
            alerts = data["data"]["alerts"]
            critical = sum(1 for a in alerts if a["labels"].get("severity") == "critical")
            warning = sum(1 for a in alerts if a["labels"].get("severity") == "warning")
            return {"critical": critical, "warning": warning}
    except:
        # 타임아웃이나 연결 거부 시 None 리턴
        return None

# ---------------------------------------------------------
# 📡 API Endpoints
# ---------------------------------------------------------

@app.get("/")
def read_root():
    return {"system": "Core Finance Service", "status": "Healthy"}

# 🌟 [인프라팀] 운영 콘솔 대시보드 API
@app.get("/dashboard/infra")
def get_infra_dashboard():
    # 1. 진짜 연결 시도 (현재 환경에선 Exception 발생 -> None 반환됨)
    real_k8s = get_real_k8s_status()
    real_prom = get_real_prometheus_alert()
    real_vpn = check_vpn_latency(settings.VPN_GATEWAY_IP, 51820)
    real_db = get_real_db_status()

    # 2. 데이터 조립 (None이면 "연결 실패" 메시지 전달)
    
    # (A) Alert 요약
    if real_prom:
        alert_data = real_prom
    else:
        # 연결 안 되면 "연결 실패" 문자열 전달 -> 프론트에서 회색 표시
        alert_data = {"critical": "연결 실패", "warning": "확인 불가"}

    # (B) EKS 상태
    if real_k8s:
        eks_data = real_k8s
    else:
        eks_data = {"nodes_ready": "연결 실패", "nodes_total": "?", "pods_crash": "?"}

    # (C) VPN 상태
    if real_vpn:
        vpn_status = real_vpn["status"]
        vpn_latency = real_vpn["latency"]
    else:
        vpn_status = "연결 실패"
        vpn_latency = "-"

    # (D) DB 상태
    if real_db:
        db_usage = real_db["usage_percent"]
        db_blocked = real_db["blocked"]
    else:
        db_usage = "연결 실패"
        db_blocked = False

    return {
        "status_summary": {
            "alert": alert_data,
            "eks": eks_data,
            "vpn": {"status": vpn_status, "latency": vpn_latency},
            "db": {"usage_percent": db_usage, "blocked": db_blocked}
        },
        "quick_links": {
            "grafana_cluster": settings.LINK_GRAFANA_CLUSTER,
            "grafana_db": settings.LINK_GRAFANA_DB,
            "hubble": settings.LINK_HUBBLE,
            "loki": settings.LINK_LOKI,
            "argocd": settings.LINK_ARGOCD,
            "runbook": settings.LINK_RUNBOOK
        },
        "recent_events": [
            {"time": "11:05:22", "severity": "CRITICAL", "target": "Pod/auth-service", "message": "CrashLoopBackOff detected"},
            {"time": "10:55:01", "severity": "WARNING", "target": "DB/PostgreSQL", "message": "Slow Query detected (>2s)"},
        ]
    }

# 🌟 [재무팀] 통계 API
@app.get("/stats")
def get_stats(db: Session = Depends(get_db)):
    total_violation = db.query(models.ViolationResult).filter(models.ViolationResult.status == "FAIL").count()
    total_transactions = db.query(models.CardTransaction).count()

    dept_ranking = db.query(
        models.ViolationResult.department, 
        func.count(models.ViolationResult.violation_id)
    ).filter(
        models.ViolationResult.status == "FAIL"
    ).group_by(
        models.ViolationResult.department
    ).all()

    dept_stats = [{"name": dept if dept else "미확인", "value": count} for dept, count in dept_ranking]
    
    # 그래프용 더미 데이터 (나중에 DB 쿼리로 교체 가능)
    daily_stats = [
        {"day": "월", "count": 0}, {"day": "화", "count": 0}, 
        {"day": "수", "count": 0}, {"day": "목", "count": 0}, 
        {"day": "금", "count": 0}, {"day": "토", "count": 0}, 
        {"day": "일", "count": 0}
    ]

    return {
        "total_transactions": total_transactions,
        "violation_count": total_violation, 
        "department_stats": dept_stats,
        "daily_violations": daily_stats, 
        "system_status": "NORMAL"
    }

# 🌟 규정 위반 내역 조회 API
@app.get("/violations")
def get_violations(db: Session = Depends(get_db)):
    return db.query(models.ViolationResult).order_by(models.ViolationResult.checked_at.desc()).limit(100).all()

# 🌟 파일 업로드 및 감사(Audit) 로직 (풀 버전)
@app.post("/transactions/upload")
async def upload_transactions(file: UploadFile = File(...), db: Session = Depends(get_db)):
    print(f"\n📢 [업로드 시작] 파일명: {file.filename}", flush=True)
    contents = await file.read()
    
    # 인코딩 처리 (한글 깨짐 방지)
    decoded_content = ""
    try: 
        decoded_content = contents.decode('utf-8')
    except: 
        try: 
            decoded_content = contents.decode('cp949')
        except: 
            return {"status": "error", "message": "파일 인코딩 오류 (UTF-8 또는 CP949 필요)"}

    # CSV 파싱
    delimiter = ',' 
    if '\t' in decoded_content: delimiter = '\t'
    
    try:
        f = io.StringIO(decoded_content)
        reader = csv.reader(f, delimiter=delimiter) 
        rows = list(reader)
    except Exception as e: 
        return {"status": "error", "message": f"파싱 실패: {e}"}
    
    if len(rows) < 2: 
        return {"status": "error", "message": "데이터가 없습니다."}

    count = 0
    
    # 데이터 한 줄씩 읽어서 검사
    for row in rows[1:]: # 헤더 제외
        if not row or all(f.strip() == "" for f in row): continue
        while len(row) < 7: row.append("") 

        try:
            # CSV 컬럼 매핑
            val_date_str = row[0].strip()
            val_card = row[1].strip()
            val_name = row[2].strip()
            val_dept = row[3].strip() 
            val_merch = row[4].strip()
            val_amt_str = row[5].strip().replace(",", "")
            val_amt = float(val_amt_str) if val_amt_str.isdigit() else 0.0
            val_cat = row[6].strip()
            
            if not val_date_str: continue

            # 🛑 감사 규칙(Audit Rule) 적용 시작
            status = "PASS"
            reasons = [] 

            # 날짜 파싱
            try:
                clean_date_str = val_date_str.replace(" AM", "").replace(" PM", "")
                if len(clean_date_str) > 16: 
                    current_time = datetime.strptime(clean_date_str[:19], "%Y-%m-%d %H:%M:%S")
                else:
                    current_time = datetime.strptime(clean_date_str[:16], "%Y-%m-%d %H:%M")
            except:
                current_time = datetime.now()

            # Rule 1: 업종 위반
            forbidden_keywords = ["유흥", "단란", "룸싸롱", "나이트", "클럽"]
            if any(word in val_cat for word in forbidden_keywords) or any(word in val_merch for word in forbidden_keywords):
                status = "FAIL"
                reasons.append("업종 위반(유흥)")

            # Rule 2: 심야 시간 제한 (23시 ~ 06시)
            hour = current_time.hour
            if hour >= 23 or hour < 6:
                status = "FAIL"
                reasons.append("심야 결제 제한(23시~06시)")

            # Rule 3: 주말 사용 제한
            if current_time.weekday() >= 5: # 5:토, 6:일
                status = "FAIL"
                reasons.append("주말 사용")

            # Rule 4: 고액 건당 한도 초과
            LIMIT_AMOUNT = 100000
            if val_amt > LIMIT_AMOUNT:
                status = "FAIL"
                reasons.append("한도 초과(단건 10만원)")

            # Rule 5: 쪼개기 결제 의심 (30분 이내 동일 가맹점 합산)
            recent_txs = db.query(models.CardTransaction).filter(
                models.CardTransaction.card_id == val_card,
                models.CardTransaction.merchant == val_merch
            ).all()

            recent_sum = 0
            is_split_detected = False
            
            for tx in recent_txs:
                try:
                    db_date_clean = tx.tx_date.replace(" AM", "").replace(" PM", "")
                    if len(db_date_clean) > 16:
                        tx_time = datetime.strptime(db_date_clean[:19], "%Y-%m-%d %H:%M:%S")
                    else:
                        tx_time = datetime.strptime(db_date_clean[:16], "%Y-%m-%d %H:%M")

                    # 30분(1800초) 이내 결제 건만 합산
                    time_diff = current_time - tx_time
                    if 0 <= time_diff.total_seconds() <= 1800:
                        recent_sum += tx.amount
                        is_split_detected = True 
                except:
                    pass 

            total_amount = val_amt + recent_sum
            
            if is_split_detected and total_amount > LIMIT_AMOUNT:
                if "한도 초과(단건 10만원)" not in reasons:
                    status = "FAIL"
                    reasons.append(f"쪼개기 결제 의심(30분 내 합계 {int(total_amount):,}원)")

            # 💾 DB 저장 (Transaction)
            tx_uuid = str(uuid.uuid4())
            new_tx = models.CardTransaction(
                tx_id = tx_uuid, tx_date = val_date_str, card_id = val_card, user_name = val_name,
                department = val_dept, merchant = val_merch, amount = val_amt, category = val_cat
            )
            db.add(new_tx)
            db.commit()

            # 💾 DB 저장 (Violation Result)
            final_reason = ", ".join(reasons) if reasons else "정상 사용"
            if not reasons: status = "PASS" 

            new_result = models.ViolationResult(
                violation_id = str(uuid.uuid4()), 
                tx_id = tx_uuid,
                tx_date = val_date_str, user_name = val_name, card_id = val_card, merchant = val_merch,
                amount = val_amt, department = val_dept,
                status = status, 
                reason = final_reason
            )
            db.add(new_result)
            db.commit() 
            count += 1
            
        except Exception as e:
            print(f"Row Error: {e}")
            continue

    print(f"✅ 총 {count}건 처리 완료", flush=True)
    return {"status": "success", "message": f"성공! {count}건이 처리되었습니다."}

# ---------------------------------------------------------
# 🕵️‍♂️ [긴급] DB에 들어있는 유저 명단 훔쳐보기 (디버깅용)
# ---------------------------------------------------------
@app.get("/debug/users")
def debug_users(db: Session = Depends(get_db)):
    try:
        # users 테이블의 모든 데이터를 긁어옴
        result = db.execute(text("SELECT * FROM users")).fetchall()
        
        # 보기 좋게 리스트로 변환
        users_list = []
        for row in result:
            users_list.append(str(row))
            
        return {"status": "success", "data": users_list}
    except Exception as e:
        return {"status": "error", "message": f"조회 실패: {e}"}
