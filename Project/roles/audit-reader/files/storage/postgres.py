# roles/audit-reader/files/storage/postgres.py

# PostgreSQL 드라이버 import
import psycopg2

# 환경 변수 접근 import
import os

# PostgreSQL 연결 정보 로드
DB_HOST = os.getenv("DB_HOST")        # DB 호스트
DB_PORT = os.getenv("DB_PORT")        # DB 포트
DB_NAME = os.getenv("DB_NAME")        # DB 이름
DB_USER = os.getenv("DB_USER")        # 읽기 전용 사용자
DB_PASSWORD = os.getenv("DB_PASSWORD")# 비밀번호

# -----------------------------
# Forensic Audit Query
# -----------------------------
def query_postgres_audit(start, end, user_id=None, action=None):
    # PostgreSQL 연결 생성
    conn = psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )

    # 커서 생성
    cur = conn.cursor()

    # 기본 쿼리 템플릿 (조건은 동적 구성)
    query = """
        SELECT *
        FROM audit.audit_events
        WHERE event_time BETWEEN %s AND %s
    """

    # 파라미터 리스트 초기화
    params = [start, end]

    # 사용자 필터가 있으면 조건 추가
    if user_id:
        query += " AND user_id = %s"
        params.append(user_id)

    # 행위 필터가 있으면 조건 추가
    if action:
        query += " AND action = %s"
        params.append(action)

    # 쿼리 실행
    cur.execute(query, params)

    # 결과 fetch
    rows = cur.fetchall()

    # 커서 및 연결 종료
    cur.close()
    conn.close()

    # 결과 반환
    return rows

