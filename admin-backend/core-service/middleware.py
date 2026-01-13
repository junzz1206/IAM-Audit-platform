from starlette.middleware.base import BaseHTTPMiddleware
from fastapi import Request
import time
import logging
import json
import socket  # 🌟 [추가] 파드 ID(hostname)를 가져오기 위해 필요
import os      # 🌟 [추가] 서비스명을 환경변수에서 가져오기 위해 필요

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("AuditLogger")

class AuditLogMiddleware(BaseHTTPMiddleware):
    def __init__(self, app):
        super().__init__(app)
        # 🌟 [추가] 서버가 뜰 때 내 파드 ID와 서비스 이름을 딱 한 번만 저장해둬 (성능 최적화)
        self.pod_id = socket.gethostname() 
        self.service_name = os.getenv("SERVICE_NAME", "my-service")

    async def dispatch(self, request: Request, call_next):
        start_time = time.time()
        
        client_ip = request.client.host
        method = request.method
        url = request.url.path
        
        try:
            response = await call_next(request)
            status_code = response.status_code
        except Exception as e:
            status_code = 500
            response = None 
            
        # --- 해빈님의 기존 로직 그대로 유지 ---
        if status_code >= 500:
            severity = "ERROR"
        elif status_code >= 400:
            severity = "WARNING"
        else:
            severity = "SUCCESS"

        is_violation = True if status_code in [401, 403] else False
        process_time = time.time() - start_time
        # ------------------------------------

        log_data = {
            "timestamp": time.strftime('%Y-%m-%d %H:%M:%S'),
            "ip": client_ip,
            "action": f"{method} {url}",
            "status_code": status_code,
            "severity": severity,
            "is_violation": is_violation,
            "duration": f"{process_time:.4f}s",
            # 🌟 [요구사항 반영] 파드 ID와 서비스명만 쏙 추가!
            "service": self.service_name,
            "pod_id": self.pod_id
        }
        
        logger.info(f"[AUDIT] {json.dumps(log_data, ensure_ascii=False)}")
        
        return response