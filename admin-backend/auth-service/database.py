from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os
from dotenv import load_dotenv

# 1. .env 파일 강제 로드
load_dotenv()

# 2. .env에서 정보 가져오기 (없으면 기본값 사용)
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "123456")
DB_HOST = os.getenv("DB_HOST", "localhost") # 터널링이니까 localhost
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "onprem_finance_db")

# 3. PostgreSQL 연결 URL 만들기
# (형식: postgresql://아이디:비번@주소:포트/DB이름)
SQLALCHEMY_DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

print(f"🔥 [DB 연결 시도] {SQLALCHEMY_DATABASE_URL}") # 디버깅용 출력

# 4. 엔진 생성 (PostgreSQL용)
try:
    engine = create_engine(SQLALCHEMY_DATABASE_URL)
    connection = engine.connect()
    print("✅ [DB 연결 성공] PostgreSQL에 접속되었습니다!")
    connection.close()
except Exception as e:
    print(f"❌ [DB 연결 실패] 에러 메시지: {e}")

# 5. 세션 설정
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# 6. DB 세션 가져오기 함수
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
