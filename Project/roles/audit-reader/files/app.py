# ==========================================================
# audit-reader (READ ONLY)
# ==========================================================

import os
import psycopg2
from flask import Flask, request, jsonify
from opensearchpy import OpenSearch, exceptions

app = Flask(__name__)

# ─────────────────────────────────────────────────────────
# Environment variables (ALL injected)
# ─────────────────────────────────────────────────────────
READ_PRIORITY = os.getenv("AUDIT_READ_PRIORITY").split(",")
OS_TIMEOUT_MS = int(os.getenv("OPENSEARCH_TIMEOUT_MS"))
OS_INDEX = os.getenv("AUDIT_OS_INDEX")
QUERY_LIMIT = int(os.getenv("AUDIT_QUERY_LIMIT"))
SERVICE_PORT = int(os.getenv("SERVICE_PORT"))

# PostgreSQL
PG_HOST = os.getenv("PG_HOST")
PG_DB = os.getenv("PG_DB")
PG_USER = os.getenv("PG_USER")
PG_PASSWORD = os.getenv("PG_PASSWORD")

# OpenSearch
OS_HOST = os.getenv("OS_HOST")
OS_PORT = int(os.getenv("OS_PORT"))

# ─────────────────────────────────────────────────────────
# Clients
# ─────────────────────────────────────────────────────────
pg_conn = psycopg2.connect(
    host=PG_HOST,
    dbname=PG_DB,
    user=PG_USER,
    password=PG_PASSWORD
)

os_client = OpenSearch(
    hosts=[{"host": OS_HOST, "port": OS_PORT}],
    timeout=OS_TIMEOUT_MS / 1000
)

# ─────────────────────────────────────────────────────────
# Query implementations
# ─────────────────────────────────────────────────────────
def query_opensearch(q):
    try:
        res = os_client.search(
            index=OS_INDEX,
            body={
                "size": QUERY_LIMIT,
                "query": {
                    "query_string": {
                        "query": q
                    }
                }
            }
        )
        hits = res["hits"]["hits"]
        return hits if hits else None
    except exceptions.OpenSearchException:
        return None


def query_postgres(q):
    with pg_conn.cursor() as cur:
        cur.execute(
            """
            SELECT *
            FROM audit_log
            WHERE message ILIKE %s
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (f"%{q}%", QUERY_LIMIT)
        )
        return cur.fetchall()


# ─────────────────────────────────────────────────────────
# HTTP API
# ─────────────────────────────────────────────────────────
@app.route("/audit/search")
def search():
    q = request.args.get("q", "")

    for backend in READ_PRIORITY:
        if backend == "opensearch":
            result = query_opensearch(q)
            if result:
                return jsonify({"source": "opensearch", "data": result})

        if backend == "postgres":
            result = query_postgres(q)
            if result:
                return jsonify({"source": "postgres", "data": result})

    return jsonify({"source": "none", "data": []}), 404


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=SERVICE_PORT)

