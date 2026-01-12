import os
from typing import List, Union
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # 1. 기본 설정
    PROJECT_NAME: str
    VERSION: str
    DEBUG: bool
    ALLOWED_ORIGINS: List[str]

    # 2. 데이터베이스 설정 (여기서 충돌 났었음!)
    # 이제 .env에 있는 값들을 "변수"로 그대로 받기만 함 (가장 깔끔!)
    DB_HOST: str
    DB_PORT: int
    DB_USER: str
    DB_PASSWORD: str
    DB_NAME: str
    
    # [핵심 수정] 함수(@property)가 아니라 '변수'로 선언해야 .env 값을 읽어옴!
    DATABASE_URL: str 

    # 3. Redis 설정
    REDIS_HOST: str
    REDIS_PORT: int
    REDIS_DB: int

    # 4. 보안 설정
    SECRET_KEY: str
    ALGORITHM: str
    ACCESS_TOKEN_EXPIRE_MINUTES: int

    class Config:
        env_file = ".env"
        env_file_encoding = 'utf-8'
        # 혹시라도 .env에 모르는 변수가 있어도 에러 내지 말고 무시해라! (안전장치)
        extra = "ignore" 

settings = Settings()