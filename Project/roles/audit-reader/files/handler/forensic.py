# roles/audit-reader/files/handlers/forensic.py

# DTO 계약 import
from dto.query import AuditQuery

# PostgreSQL 조회 함수 import
from storage.postgres import query_postgres_audit

# FastAPI 의존성 주입 import
from fastapi import Depends

# -----------------------------
# Forensic Query Handler
# -----------------------------
def handle(query: AuditQuery = Depends()):
    # forensic 요청은 audit-query-api에서 명시적으로만 전달됨
    # 실시간 성능 요구 없음 (정합성 우선)

    # PostgreSQL read-only 조회 수행
    result = query_postgres_audit(
        start=query.start,        # 조회 시작 시각
        end=query.end,            # 조회 종료 시각
        user_id=query.user_id,    # 사용자 필터
        action=query.action       # 행위 필터
    )

    # 결과 반환
    return result

