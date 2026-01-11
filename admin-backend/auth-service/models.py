from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from database import Base
import uuid

# 1. 사용자 정보 (iam.users) -> 🔢 Integer (숫자)
class User(Base):
    __tablename__ = "users"
    __table_args__ = {"schema": "iam"}

    user_id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    status = Column(String, default='ACTIVE')

# 2. 비밀번호 (iam.credentials) -> 🔢 Integer (숫자)
class Credential(Base):
    __tablename__ = "credentials"
    __table_args__ = {"schema": "iam"}

    credential_id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("iam.users.user_id"))
    password_hash = Column(String)

# 3. 역할 정의 (iam.roles) -> 🔤 UUID (문자열)
class Role(Base):
    __tablename__ = "roles"
    __table_args__ = {"schema": "iam"}

    role_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    role_name = Column(String, unique=True)

# 4. 사용자와 역할 연결 (iam.user_role) -> 🍜 짬뽕 (숫자 + 문자열)
class UserRole(Base):
    __tablename__ = "user_role"
    __table_args__ = {"schema": "iam"}

    user_id = Column(Integer, ForeignKey("iam.users.user_id"), primary_key=True)
    role_id = Column(UUID(as_uuid=True), ForeignKey("iam.roles.role_id"), primary_key=True)
