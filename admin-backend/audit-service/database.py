from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os
from dotenv import load_dotenv

# 1. .env 로드
load_dotenv()

# 2. 환경변수 가져오기 (없으면 기본값)
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "123456")
DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "audit_db") # 여기가 audit_db여야 함!

# 3. 연결 URL
SQLALCHEMY_DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

print(f"🔥 [Audit DB 연결 시도] {SQLALCHEMY_DATABASE_URL}")

# 4. 엔진 생성
try:
    engine = create_engine(SQLALCHEMY_DATABASE_URL)
    # 연결 테스트
    with engine.connect() as connection:
        print(f"✅ [Audit DB 연결 성공] {DB_NAME}에 접속했습니다!")
except Exception as e:
    print(f"❌ [Audit DB 연결 실패] {e}")

# 5. 세션 공장
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()