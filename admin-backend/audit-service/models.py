from sqlalchemy import Column, String, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from database import Base
import uuid

# ⚠️ 성민님 피드백 반영: audit_db는 'audit' 스키마 사용!

class AuditEvent(Base):
    __tablename__ = "audit_events"
    
    # ⭐ 여기가 핵심! (스키마를 'audit'으로 지정)
    __table_args__ = {"schema": "audit"}

    audit_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    event_type = Column(String, index=True)   # LOGIN, ACCESS 등
    
    # actor_id는 'admin' 같은 문자열일 수도, ID일 수도 있어서 String 처리
    actor_id = Column(String, nullable=True)  
    actor_type = Column(String, nullable=True) 
    
    target_id = Column(String, nullable=True)  
    target_type = Column(String, nullable=True) 
    
    action = Column(String)       # READ, WRITE 등
    result = Column(String)       # SUCCESS, FAILURE
    
    source_ip = Column(String)    # 접속 IP
    request_id = Column(String, nullable=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())