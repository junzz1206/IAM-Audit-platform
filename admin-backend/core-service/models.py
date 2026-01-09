from sqlalchemy import Column, String, Integer, Float, DateTime, Boolean, Text
from database import Base 
import datetime
import uuid

# 1. 원본 데이터
class CardTransaction(Base):
    __tablename__ = "card_transactions_raw"

    tx_id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    card_id = Column(String, index=True, nullable=False) 
    user_name = Column(String)
    department = Column(String) 
    merchant = Column(String)
    amount = Column(Float)
    tx_date = Column(String) 
    category = Column(String) 
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

# 2. 분석 결과 (위반 내역) - 🌟 여기에 빠진 칸들 다 추가함!
class ViolationResult(Base):
    __tablename__ = "violation_results"

    violation_id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    tx_id = Column(String, index=True)
    
    # 통계 및 화면 표시용 데이터 복사
    tx_date = Column(String)      # 🌟 날짜 추가
    user_name = Column(String)    # 🌟 이름 추가
    card_id = Column(String)      # 🌟 카드번호 추가
    merchant = Column(String)     # 🌟 가맹점 추가
    amount = Column(Float)        # 🌟 금액 추가
    department = Column(String)
    
    status = Column(String) 
    reason = Column(Text)
    checked_at = Column(DateTime, default=datetime.datetime.utcnow)
