# roles/audit-reader/files/router.py

# FastAPI 라우터 객체를 사용하기 위한 import
from fastapi import APIRouter

# 각 쿼리 유형별 handler 모듈 import
from handlers import realtime              # 최근 조회 전용 handler
from handlers import range as range_handler # 기간 조회 전용 handler
from handlers import forensic               # DB 감사 전용 handler

# audit-reader 전체에서 사용하는 Router 객체 생성
# prefix는 audit-query-api와의 계약(API Contract)
router = APIRouter(prefix="/read")

# -----------------------------
# Realtime Query Endpoint
# -----------------------------

# 최근 N분 이내 조회 전용 엔드포인트 등록
router.add_api_route(
    "/realtime",                # audit-query-api에서 호출할 경로
    realtime.handle,             # 실제 실행 함수
    methods=["GET"],             # 조회 전용
    summary="Realtime audit query (OpenSearch hot index)"
)

# -----------------------------
# Range Query Endpoint
# -----------------------------

# 기간 조회(대량 데이터) 전용 엔드포인트 등록
router.add_api_route(
    "/range",                    # 기간 검색용 경로
    range_handler.handle,         # 실행 함수
    methods=["GET"],              # 조회 전용
    summary="Range audit query (OpenSearch warm/cold index)"
)

# -----------------------------
# Forensic Query Endpoint
# -----------------------------

# 법적/정합성 감사용 DB 직접 조회 엔드포인트 등록
router.add_api_route(
    "/forensic",                 # forensic 전용 경로
    forensic.handle,              # PostgreSQL 조회 함수
    methods=["GET"],              # 조회 전용
    summary="Forensic audit query (PostgreSQL read-only)"
)

