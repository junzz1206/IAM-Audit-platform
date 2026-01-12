from sqlalchemy import Column, String, Integer, Float, DateTime, Text, Boolean, Date, Numeric, SmallInteger
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.sql import func
from database import Base
import uuid

# ⚠️ 모든 테이블은 'finance' 스키마 사용

# 1. 법인카드 거래 원본 (finance.card_transactions_raw)
class CardTransaction(Base):
    __tablename__ = "card_transactions_raw"
    __table_args__ = {"schema": "finance"}

    # 실제 DB: tx_id (uuid)
    tx_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # 실제 DB: card_id (text), user_uuid (uuid)
    card_id = Column(String, nullable=False)
    user_uuid = Column(UUID(as_uuid=True), nullable=False) # 🌟 user_id 아님!
    
    merchant = Column(String)
    amount = Column(Numeric) # 🌟 DB가 numeric임
    currency = Column(String, default="KRW")
    user_name = Column(String, nullable=True)
    department = Column(String)
    merchant_name = Column(String, nullable=True)
    category = Column(String, nullable=True)
    
    tx_date = Column(DateTime(timezone=True), nullable=False)
    raw_payload = Column(JSONB) 
    
    # 실제 DB: created_at (timestamp)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

# 2. 규정 위반 심사 결과 (finance.violation_results)
class ViolationResult(Base):
    __tablename__ = "violation_results"
    __table_args__ = {"schema": "finance"}

    violation_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tx_id = Column(UUID(as_uuid=True), index=True) 
    
    # 🌟 중요: DB에 integer로 되어 있음 (NOT NULL)
    rule_id = Column(Integer, nullable=False, default=1) 
    
    status = Column(String, nullable=False)
    reason = Column(Text)
    
    # 🌟 DB에 추가된 필수 컬럼들
    is_violation = Column(Boolean, nullable=False, default=False)
    severity = Column(SmallInteger, nullable=False, default=1) # 1:Info, 2:Warn, 3:Critical
    
    # 실제 DB: created_at (checked_at 아님!)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

# 3. 심사 규칙 (finance.usage_rules)
class UsageRule(Base):
    __tablename__ = "usage_rules"
    __table_args__ = {"schema": "finance"}

    rule_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    rule_type = Column(String)
    rule_value = Column(JSONB)
    active = Column(Boolean, default=True)

# 4. 공휴일 목록 (finance.holidays)
class Holiday(Base):
    __tablename__ = "holidays"
    __table_args__ = {"schema": "finance"}
    
    start_date = Column(Date, primary_key=True) 
    end_date = Column(Date)
    description = Column(String)