# roles/audit-reader/files/handlers/range.py

# DTO 계약 import
from dto.query import AuditQuery

# OpenSearch cold/warm index 접근 함수 import
from storage.opensearch import query_range_index

# FastAPI 의존성 주입 import
from fastapi import Depends

# -----------------------------
# Range Query Handler
# -----------------------------
def handle(query: AuditQuery = Depends()):
    # 기간 조회는 데이터량이 많을 수 있음
    # pagination / scroll / search_after는 storage 계층에서 처리

    # OpenSearch range index 조회 수행
    result = query_range_index(
        start=query.start,        # 시작 시각
        end=query.end,            # 종료 시각
        user_id=query.user_id,    # 사용자 필터
        action=query.action       # 행위 필터
    )

    # 결과 반환
    return result

