from sqlalchemy import Column, String, Integer, DateTime, Text, JSON, DECIMAL
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from database import Base
import uuid

# 1. 감사 로그 테이블 (ERD: audit_events)
class AuditEvent(Base):
    __tablename__ = "audit_events"

    audit_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    event_type = Column(String)  # LOGIN, ACCESS 등
    actor_id = Column(String)    # 행위자 ID
    target_id = Column(String)   # 대상 ID
    action = Column(String)      # READ, WRITE 등
    result = Column(String)      # SUCCESS, FAILURE
    source_ip = Column(String)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

# 2. 카드 거래 내역 (ERD: card_transactions_raw) - 재무팀 통계용
class CardTransaction(Base):
    __tablename__ = "card_transactions_raw"

    tx_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    amount = Column(DECIMAL)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    # 필요한 컬럼만 정의 (통계용)

# 3. 위반 결과 (ERD: violation_results) - 재무팀 통계용
class ViolationResult(Base):
    __tablename__ = "violation_results"

    violation_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    status = Column(String) # PASS / FAIL
    reason = Column(Text)
    checked_at = Column(DateTime(timezone=True), server_default=func.now())
