# roles/audit-reader/files/dto/query.py

# 데이터 검증 및 직렬화를 위한 Pydantic import
from pydantic import BaseModel

# 날짜/시간 타입 사용을 위한 import
from datetime import datetime

# Optional 타입 사용을 위한 import
from typing import Optional

# Audit Query에 대한 명시적 계약 정의
class AuditQuery(BaseModel):
    # 조회 시작 시각 (ISO-8601)
    start: datetime

    # 조회 종료 시각 (ISO-8601)
    end: datetime

    # 특정 사용자 기준 조회 시 사용 (선택)
    user_id: Optional[str] = None

    # 특정 행위(action) 기준 조회 시 사용 (선택)
    action: Optional[str] = None

