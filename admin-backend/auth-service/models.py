from sqlalchemy import Column, String, Integer, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base
import uuid

# ⚠️ 모든 테이블은 'iam' 스키마 (성민님 DB 완벽 반영)

# 1. Users 테이블
class User(Base):
    __tablename__ = "users"
    __table_args__ = {"schema": "iam"}

    user_id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, nullable=False)
    email = Column(String, nullable=False)
    status = Column(String, default="ACTIVE")
    
    # 🌟 [수정] 성민님 DB에 맞춰서 created_at -> updated_at으로 변경!
    updated_at = Column(DateTime(timezone=True), server_default=func.now())

    # 관계 설정
    credentials = relationship("Credential", back_populates="user")
    user_roles = relationship("UserRole", back_populates="user")

# 2. Roles 테이블
class Role(Base):
    __tablename__ = "roles"
    __table_args__ = {"schema": "iam"}

    role_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    role_name = Column(String, unique=True, nullable=False)
    description = Column(String)

    user_roles = relationship("UserRole", back_populates="role")
    role_permissions = relationship("RolePermission", back_populates="role")

# 3. User_Role 매핑 테이블
class UserRole(Base):
    __tablename__ = "user_role"
    __table_args__ = {"schema": "iam"}

    user_id = Column(Integer, ForeignKey("iam.users.user_id"), primary_key=True)
    role_id = Column(UUID(as_uuid=True), ForeignKey("iam.roles.role_id"), primary_key=True)

    user = relationship("User", back_populates="user_roles")
    role = relationship("Role", back_populates="user_roles")

# 4. Credentials 테이블
class Credential(Base):
    __tablename__ = "credentials"
    __table_args__ = {"schema": "iam"}

    credential_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("iam.users.user_id"))
    password_hash = Column(String, nullable=False)
    algorithm = Column(String, default="bcrypt")
    
    # 🌟 여기는 성민님이 updated_at으로 잘 만드셔서 그대로 유지!
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="credentials")

# 5. Permissions 테이블
class Permission(Base):
    __tablename__ = "permissions"
    __table_args__ = {"schema": "iam"}

    permission_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    resource = Column(String)
    action = Column(String)

    role_permissions = relationship("RolePermission", back_populates="permission")

# 6. Role_Permission 매핑 테이블
class RolePermission(Base):
    __tablename__ = "role_permission"
    __table_args__ = {"schema": "iam"}

    role_id = Column(UUID(as_uuid=True), ForeignKey("iam.roles.role_id"), primary_key=True)
    permission_id = Column(UUID(as_uuid=True), ForeignKey("iam.permissions.permission_id"), primary_key=True)

    role = relationship("Role", back_populates="role_permissions")
    permission = relationship("Permission", back_populates="role_permissions")