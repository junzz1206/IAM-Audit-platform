from sqlalchemy import Column, String, Integer, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from database import Base
import datetime
import uuid

class User(Base):
    __tablename__ = "users"

    user_id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    username = Column(String, unique=True, index=True)
    email = Column(String)
    status = Column(String, default="ACTIVE")
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    credentials = relationship("Credential", back_populates="user")
    user_roles = relationship("UserRole", back_populates="user")

class Credential(Base):
    __tablename__ = "credentials"

    credential_id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.user_id"))
    password_hash = Column(String)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="credentials")

class Role(Base):
    __tablename__ = "roles"

    role_id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    role_name = Column(String, unique=True)
    description = Column(String)

    user_roles = relationship("UserRole", back_populates="role")

class UserRole(Base):
    __tablename__ = "user_role"

    user_id = Column(String, ForeignKey("users.user_id"), primary_key=True)
    role_id = Column(String, ForeignKey("roles.role_id"), primary_key=True)

    user = relationship("User", back_populates="user_roles")
    role = relationship("Role", back_populates="user_roles")
