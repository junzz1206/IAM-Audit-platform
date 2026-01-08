# roles/audit-reader/files/storage/opensearch.py

# OpenSearch 클라이언트 import
from opensearchpy import OpenSearch

# 환경 변수 접근을 위한 import
import os

# OpenSearch 접속 정보 환경변수에서 로드
OPENSEARCH_HOST = os.getenv("OPENSEARCH_HOST")   # OpenSearch 호스트
OPENSEARCH_PORT = int(os.getenv("OPENSEARCH_PORT", "9200"))  # 포트

# OpenSearch 클라이언트 생성
client = OpenSearch(
    hosts=[{"host": OPENSEARCH_HOST, "port": OPENSEARCH_PORT}]
)

# -----------------------------
# Hot Index Query
# -----------------------------
def query_hot_index(start, end, user_id=None, action=None):
    # 최근 데이터 전용 hot index 조회
    # index 이름은 정책적으로 관리
    index_name = os.getenv("OPENSEARCH_HOT_INDEX")

    # 실제 검색 로직은 DSL 구성으로 처리
    return client.search(
        index=index_name,
        body={
            "query": {
                "range": {
                    "timestamp": {
                        "gte": start.isoformat(),
                        "lte": end.isoformat()
                    }
                }
            }
        }
    )

# -----------------------------
# Range Index Query
# -----------------------------
def query_range_index(start, end, user_id=None, action=None):
    # 기간 조회용 warm/cold index 조회
    index_name = os.getenv("OPENSEARCH_RANGE_INDEX")

    # 검색 수행
    return client.search(
        index=index_name,
        body={
            "query": {
                "range": {
                    "timestamp": {
                        "gte": start.isoformat(),
                        "lte": end.isoformat()
                    }
                }
            }
        }
    )

