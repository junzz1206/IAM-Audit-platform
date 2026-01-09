import redis
from config import settings

r = redis.Redis(
    host=settings.REDIS_HOST,
    port=settings.REDIS_PORT,
    db=settings.REDIS_DB,
    decode_responses=True
)

def save_login_session(user_id: str, token: str, expire: int = 3600):
    key = f"user:{user_id}"
    r.set(key, token, ex=expire)

def check_login_session(user_id: str):
    key = f"user:{user_id}"
    return r.get(key)

def delete_login_session(user_id: str):
    key = f"user:{user_id}"
    r.delete(key)
