# ==========================================================
# audit-query-api
# Purpose:
# - External-facing Audit Query API
# - Validate access token via IAM
# - Forward query to audit-reader
# - NO direct DB / OpenSearch access
# ==========================================================

import os                                  # 환경변수 접근용
import requests                            # 내부 서비스 호출용
from flask import Flask, request, jsonify  # REST API 구성

app = Flask(__name__)                      # Flask 앱 생성

# ─────────────────────────────────────────────────────────
# Environment variables (ALL injected from ConfigMap)
# ─────────────────────────────────────────────────────────
SERVICE_PORT = int(os.getenv("SERVICE_PORT"))          # API 서비스 포트
AUDIT_READER_URL = os.getenv("AUDIT_READER_URL")       # audit-reader 내부 주소
IAM_VALIDATE_URL = os.getenv("IAM_VALIDATE_URL")       # IAM 토큰 검증 URL

# ─────────────────────────────────────────────────────────
# Helper: IAM token validation
# ─────────────────────────────────────────────────────────
def validate_token(token):
    """
    IAM 서비스에 토큰을 전달하여
    - 유효성
    - 권한 여부
    를 검증한다
    """
    try:
        resp = requests.post(
            IAM_VALIDATE_URL,                           # IAM 검증 엔드포인트
            headers={"Authorization": token},           # 토큰 전달
            timeout=2                                   # IAM 장애 시 빠른 실패
        )
        return resp.status_code == 200                  # 200이면 통과
    except requests.RequestException:
        return False                                   # IAM 장애 시 차단

# ─────────────────────────────────────────────────────────
# API: Audit log search
# ─────────────────────────────────────────────────────────
@app.route("/audit/search", methods=["GET"])
def audit_search():
    # Authorization 헤더에서 토큰 추출
    token = request.headers.get("Authorization")

    # 토큰이 없으면 즉시 차단
    if not token:
        return jsonify({"error": "missing token"}), 401

    # IAM을 통한 토큰 검증
    if not validate_token(token):
        return jsonify({"error": "unauthorized"}), 403

    # 검색 쿼리 파라미터 수집
    query = request.args.get("q", "")

    try:
        # audit-reader로 조회 요청 전달
        resp = requests.get(
            f"{AUDIT_READER_URL}/audit/search",
            params={"q": query},
            timeout=3                                   # reader 장애 대비
        )

        # audit-reader 응답 그대로 반환
        return jsonify(resp.json()), resp.status_code

    except requests.RequestException:
        # audit-reader 장애 시 명확한 에러 반환
        return jsonify({"error": "audit-reader unavailable"}), 503


# ─────────────────────────────────────────────────────────
# Application entrypoint
# ─────────────────────────────────────────────────────────
if __name__ == "__main__":
    # Kubernetes 환경에서 0.0.0.0 바인딩
    app.run(host="0.0.0.0", port=SERVICE_PORT)

