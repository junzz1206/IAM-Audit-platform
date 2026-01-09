import redis
from config import settings

# 1. 진짜 Redis 연결
# 도커 내부망(network)을 통해 redis 컨테이너와 연결됨
r = redis.Redis(
    host=settings.REDIS_HOST,
    port=settings.REDIS_PORT,
    db=settings.REDIS_DB,
    decode_responses=True
)

# 2. 로그인 정보 저장 (최초 로그인 시)
def save_login_session(user_id: str, token: str, expire: int = 3600):
    key = f"user:{user_id}"
    # ex=expire : 설정한 시간(3600초) 뒤에 자동 삭제
    r.set(key, token, ex=expire)
    print(f"✅ [Real Redis] Saved: {key} -> {token} (Expires in {expire}s)")

# 3. 로그인 정보 확인 (매번 페이지 이동할 때마다 실행)
def check_login_session(user_id: str):
    key = f"user:{user_id}"
    token = r.get(key)

    if token:
        # 핵심 기능: 활동 감지 시 수명 연장!
        # 사용자가 살아있으면(토큰 조회 성공), 카운트다운을 다시 3600초로 리셋함.
        r.expire(key, 3600)
        print(f"[Session Extended] {user_id} 님의 로그인 시간이 1시간 연장되었습니다.")
    else:
        print(f"[Session Expired] {user_id} 님의 세션이 만료되었습니다.")

    return token

# 4. 로그아웃 (토큰 즉시 삭제)
def delete_login_session(user_id: str):
    key = f"user:{user_id}"
    r.delete(key)
    print(f"[Real Redis] Deleted: {key}")
