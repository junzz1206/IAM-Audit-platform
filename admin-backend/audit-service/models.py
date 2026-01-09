from sqlalchemy import Column, String, Integer, DateTime, Text
from database import Base
import datetime
import uuid

class AuditLog(Base):
    __tablename__ = "audit_logs"

    log_id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    service_name = Column(String)  # 어느 서비스에서 온 로그인지 (Auth? Core?)
    user_id = Column(String, nullable=True)
    ip_address = Column(String)
    action = Column(String)        # 무슨 행동을 했는지
    status = Column(String)        # 성공/실패 여부
    severity = Column(String)      # 심각도 (INFO, WARNING, ERROR)
    details = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
