from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os
from dotenv import load_dotenv

# 1. .env 파일 로드
# (파일이 없으면 없는 대로, 있으면 있는 대로 진행)
load_dotenv()

# 2. 환경변수 가져오기 (없으면 기본값 사용)
# 🌟 해빈님의 .env 파일 내용을 기준으로 가져옵니다.
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "123456")
DB_HOST = os.getenv("DB_HOST", "127.0.0.1") 
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "finance_db") # 기본값도 'finance_db'로 안전하게 설정

# 3. 주소 조립
SQLALCHEMY_DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

# 🛑 [진단 로그] 터미널에 이 부분이 어떻게 찍히는지 꼭 봐주세요!
print("------------------------------------------------------")
print(f"🔥 [진단] .env 로드 결과 확인")
print(f"   - DB 이름: {DB_NAME}")  
print(f"   - 접속 주소: {SQLALCHEMY_DATABASE_URL.replace(f':{DB_PASSWORD}@', ':******@')}")
print("------------------------------------------------------")

# 4. 엔진 생성 및 연결 테스트
try:
    engine = create_engine(SQLALCHEMY_DATABASE_URL)
    
    # 실제 접속 시도
    with engine.connect() as conn:
        print(f"✅ [성공] '{DB_NAME}' DB에 접속되었습니다! (문제 해결 완료)")
        
except Exception as e:
    print(f"❌ [실패] DB 연결 에러 발생!")
    print(f"   - 원인: {e}")
    # 연결 실패 시 힌트 제공
    if "does not exist" in str(e):
        print("   👉 힌트: DB 이름이 틀렸습니다. (혹시 finance_db가 아닌가요?)")
    elif "password authentication" in str(e):
        print("   👉 힌트: 비밀번호가 틀렸습니다.")
    elif "Connection refused" in str(e):
        print("   👉 힌트: DB가 켜져 있지 않거나(127.0.0.1:5432), IP가 틀렸습니다.")

# 5. 세션 설정
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()