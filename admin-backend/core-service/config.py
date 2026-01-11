import os
from typing import List
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # --------------------------------------------------------
    # 1. 기본 프로젝트 설정 (이건 보통 코드에 박아둠)
    # --------------------------------------------------------
    PROJECT_NAME: str = "Core Finance Service"
    VERSION: str = "1.0.0"
    DEBUG: bool = True
    ALLOWED_ORIGINS: List[str] = ["*"]

    # --------------------------------------------------------
    # 2. 필수 인프라 (DB, Redis, Security) - 엄격 모드!
    # --------------------------------------------------------
    DB_HOST: str
    DB_PORT: int
    DB_USER: str
    DB_PASSWORD: str
    DB_NAME: str

    REDIS_HOST: str
    REDIS_PORT: int
    REDIS_DB: int

    SECRET_KEY: str
    ALGORITHM: str
    ACCESS_TOKEN_EXPIRE_MINUTES: int

    # --------------------------------------------------------
    # 3. [NEW] 인프라 모니터링 & 퀵 링크
    # (.env 파일에 이 변수들이 없으면 에러가 납니다)
    # --------------------------------------------------------
    
    # (1) Kubernetes
    KUBE_CONFIG_PATH: str 

    # (2) Prometheus
    PROMETHEUS_URL: str

    # (3) 실제 DB 모니터링용
    REAL_DB_HOST: str
    REAL_DB_PORT: int
    REAL_DB_USER: str
    REAL_DB_PASSWORD: str
    REAL_DB_NAME: str

    # (4) VPN 상태 체크
    VPN_GATEWAY_IP: str

    # (5) 퀵 메뉴 (Quick Links)
    LINK_GRAFANA_CLUSTER: str
    LINK_GRAFANA_DB: str
    LINK_HUBBLE: str
    LINK_LOKI: str
    LINK_ARGOCD: str
    LINK_RUNBOOK: str

    class Config:
        env_file = ".env"
        extra = "ignore" 

settings = Settings()
