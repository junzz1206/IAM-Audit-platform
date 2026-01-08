# roles/audit-reader/files/handlers/realtime.py

# DTO를 이용해 입력을 강제하기 위한 import
from dto.query import AuditQuery

# OpenSearch 저장소 접근 함수 import
from storage.opensearch import query_hot_index

# FastAPI에서 쿼리 파라미터를 자동 매핑하기 위한 import
from fastapi import Depends

# -----------------------------
# Realtime Query Handler
# -----------------------------
def handle(query: AuditQuery = Depends()):
    # audit-query-api에서 이미 "realtime"으로 분기된 요청만 도착
    # 여기서는 조건 판단을 절대 하지 않는다

    # OpenSearch hot index 조회 함수 호출
    result = query_hot_index(
        start=query.start,        # 조회 시작 시각 전달
        end=query.end,            # 조회 종료 시각 전달
        user_id=query.user_id,    # 사용자 필터 전달
        action=query.action       # 행위 필터 전달
    )

    # 조회 결과 그대로 반환
    return result

