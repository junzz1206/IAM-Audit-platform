import redis
from config import settings
import json

# 1. Redis 연결 (DB 1번 사용)
r = redis.Redis(
    host=settings.REDIS_HOST,
    port=settings.REDIS_PORT,
    db=settings.REDIS_DB, 
    decode_responses=True
)

# 2. 로그인 세션 저장
def save_login_session(user_id: int, token: str, role: str, expire: int = 3600):
    key = f"user:{user_id}"
    data = {
        "token": token,
        "role": role
    }
    r.set(key, json.dumps(data), ex=expire)
    print(f"✅ [Redis] Saved Session: {key}")

# 3. 세션 확인 (필요시)
def get_login_session(user_id: int):
    key = f"user:{user_id}"
    data = r.get(key)
    return json.loads(data) if data else None

# 4. 로그아웃
def delete_login_session(user_id: int):
    key = f"user:{user_id}"
    r.delete(key)