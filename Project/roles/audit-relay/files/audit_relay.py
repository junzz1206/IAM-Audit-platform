# ----------------------------------------------------------
# Audit Relay Worker
# ----------------------------------------------------------
# 역할:
# - PostgreSQL audit.audit_events 테이블에서
#   아직 전송되지 않은(dispatched = false) 로그를 조회
# - OpenSearch로 bulk index
# - 성공/실패 결과를 DB에 반영
# - NRT (Near Real-Time) 동작
# ----------------------------------------------------------

import os                      # 환경변수 접근
import time                    # polling interval 제어
import psycopg2                # PostgreSQL 클라이언트
from psycopg2.extras import RealDictCursor  # dict 형태 결과
from opensearchpy import OpenSearch, helpers  # OpenSearch 클라이언트

# ----------------------------------------------------------
# Environment Variables (Hardcoding 금지)
# ----------------------------------------------------------
PG_DSN = os.getenv("PG_DSN")                       # PostgreSQL DSN
OS_HOST = os.getenv("OS_HOST")                     # OpenSearch 호스트
OS_PORT = int(os.getenv("OS_PORT", "9200"))        # OpenSearch 포트
OS_INDEX = os.getenv("OS_INDEX")                   # OpenSearch 인덱스
BATCH_SIZE = int(os.getenv("BATCH_SIZE", "200"))   # batch 처리 크기
POLL_INTERVAL = float(os.getenv("POLL_INTERVAL_SEC", "0.5"))  # NRT 주기

# ----------------------------------------------------------
# PostgreSQL Connection
# ----------------------------------------------------------
def get_pg_conn():
    # PostgreSQL 연결 생성
    return psycopg2.connect(PG_DSN)

# ----------------------------------------------------------
# OpenSearch Client
# ----------------------------------------------------------
def get_os_client():
    # OpenSearch 클라이언트 생성
    return OpenSearch(
        hosts=[{"host": OS_HOST, "port": OS_PORT}],
        timeout=30,
        max_retries=3,
        retry_on_timeout=True
    )

# ----------------------------------------------------------
# SQL Definitions
# ----------------------------------------------------------

# 아직 전송되지 않은 audit 로그를 가져오면서
# 다른 워커와 충돌하지 않도록 row lock 적용
FETCH_AND_LOCK_SQL = """
WITH target AS (
    SELECT audit_id
    FROM audit.audit_events
    WHERE dispatched = FALSE
      AND dispatching = FALSE
    ORDER BY created_at
    FOR UPDATE SKIP LOCKED
    LIMIT %s
)
UPDATE audit.audit_events e
SET dispatching = TRUE
FROM target
WHERE e.audit_id = target.audit_id
RETURNING
    e.audit_id,
    e.event_type,
    e.actor_id,
    e.actor_type,
    e.target_type,
    e.target_id,
    e.action,
    e.result,
    e.source_ip,
    e.request_id,
    e.created_at;
"""

# OpenSearch 전송 성공 시 상태 업데이트
MARK_SUCCESS_SQL = """
UPDATE audit.audit_events
SET dispatched = TRUE,
    dispatching = FALSE,
    dispatched_at = NOW(),
    dispatch_error = NULL
WHERE audit_id = ANY(%s::uuid[]);
"""

# OpenSearch 전송 실패 시 상태 복구
MARK_FAIL_SQL = """
UPDATE audit.audit_events
SET dispatching = FALSE,
    dispatch_error = %s
WHERE audit_id = ANY(%s::uuid[]);
"""

# ----------------------------------------------------------
# Main Loop
# ----------------------------------------------------------
def main():
    # PostgreSQL 연결
    pg_conn = get_pg_conn()
    pg_conn.autocommit = False

    # OpenSearch 클라이언트
    os_client = get_os_client()

    while True:
        try:
            # ------------------------------
            # 1. Fetch audit logs from DB
            # ------------------------------
            with pg_conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(FETCH_AND_LOCK_SQL, (BATCH_SIZE,))
                rows = cur.fetchall()
                pg_conn.commit()

            # 처리할 데이터가 없으면 잠시 대기
            if not rows:
                time.sleep(POLL_INTERVAL)
                continue

            # ------------------------------
            # 2. Build OpenSearch bulk actions
            # ------------------------------
            actions = []
            audit_ids = []

            for row in rows:
                audit_ids.append(str(row["audit_id"]))

                # OpenSearch 문서 구성
                actions.append({
                    "_op_type": "index",
                    "_index": OS_INDEX,
                    "_id": str(row["audit_id"]),   # idempotent 보장
                    "_source": {
                        "audit_id": str(row["audit_id"]),
                        "event_type": row["event_type"],
                        "actor": {
                            "id": str(row["actor_id"]) if row["actor_id"] else None,
                            "type": row["actor_type"]
                        },
                        "target": {
                            "id": str(row["target_id"]) if row["target_id"] else None,
                            "type": row["target_type"]
                        },
                        "action": row["action"],
                        "result": row["result"],
                        "source_ip": row["source_ip"],
                        "request_id": row["request_id"],
                        "created_at": row["created_at"].isoformat()
                    }
                })

            # ------------------------------
            # 3. Send to OpenSearch
            # ------------------------------
            helpers.bulk(os_client, actions, raise_on_error=False)

            # ------------------------------
            # 4. Mark success in DB
            # ------------------------------
            with pg_conn.cursor() as cur:
                cur.execute(MARK_SUCCESS_SQL, (audit_ids,))
                pg_conn.commit()

        except Exception as e:
            # ------------------------------
            # 5. Error handling
            # ------------------------------
            error_message = str(e)[:2000]

            try:
                with pg_conn.cursor() as cur:
                    cur.execute(MARK_FAIL_SQL, (error_message, audit_ids))
                    pg_conn.commit()
            except Exception:
                pg_conn.rollback()

            # 오류 발생 시 잠시 대기 후 재시도
            time.sleep(POLL_INTERVAL)

# ----------------------------------------------------------
# Entrypoint
# ----------------------------------------------------------
if __name__ == "__main__":
    main()

