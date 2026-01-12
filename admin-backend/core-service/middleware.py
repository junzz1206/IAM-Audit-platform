from starlette.middleware.base import BaseHTTPMiddleware
from fastapi import Request
import time
import logging
import json

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("AuditLogger")

class AuditLogMiddleware(BaseHTTPMiddleware):
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
            
        if status_code >= 500:
            severity = "ERROR"
        elif status_code >= 400:
            severity = "WARNING"
        else:
            severity = "SUCCESS"

        is_violation = True if status_code in [401, 403] else False

        process_time = time.time() - start_time
        
        log_data = {
            "timestamp": time.strftime('%Y-%m-%d %H:%M:%S'),
            "ip": client_ip,
            "action": f"{method} {url}",
            "status_code": status_code,
            "severity": severity,
            "is_violation": is_violation,
            "duration": f"{process_time:.4f}s"
        }
        
        logger.info(f"[AUDIT] {json.dumps(log_data, ensure_ascii=False)}")
        
        return response