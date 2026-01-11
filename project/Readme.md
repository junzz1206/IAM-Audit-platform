# ==========================================================
# On-Premise Automation Platform
# (Ansible + PostgreSQL + Kubernetes)
# ==========================================================
#
# 이 저장소는 온프레미스 환경에서
# PostgreSQL 데이터베이스와 여러 애플리케이션을
# 안전하게 자동 구축/운영하기 위한
# Ansible 기반 자동화 프로젝트입니다.
#
# ----------------------------------------------------------
# 핵심 설계 원칙
# ----------------------------------------------------------
#
# - DB 계정/비밀번호를 코드에 저장하지 않음
# - VPN + OS + DB 설정을 통한 경계 기반 접근 제어
# - DDL / DCL / DML / 인프라 설정의 명확한 분리
# - 모든 인프라는 코드로 재현 가능
# - 감사(Audit) 대응이 가능한 구조
#
# ==========================================================
# 디렉터리 구조
# ==========================================================
#
# ansible/
# ├── inventories/
# │   └── onprem/
# │       ├── hosts.yml
# │       └── group_vars/
# │           └── all.yml
# │
# ├── playbooks/
# │   ├── site.yml
# │   │
# │   ├── database/
# │   │   ├── install_postgres.yml
# │   │   ├── init_schema.yml
# │   │   └── apply_roles.yml
# │   │
# │   └── apps/
# │       ├── deploy_ingest.yml
# │       ├── deploy_rule_engine.yml
# │       ├── deploy_audit_writer.yml
# │       └── deploy_iam.yml
# │
# ├── roles/
# │   ├── postgres/
# │   │   ├── tasks/
# │   │   │   ├── install.yml
# │   │   │   ├── init.yml
# │   │   │   └── roles.yml
# │   │   └── templates/
# │   │       └── postgresql.conf.j2
# │   │
# │   ├── ingest-service/
# │   ├── finance-rule-engine/
# │   ├── audit-writer/
# │   └── iam-service/
# │
# └── README.md
#
# ==========================================================
# inventories/onprem
# ==========================================================
#
# hosts.yml
# - 온프레미스 대상 서버 정의
#
# group_vars/all.yml
# - 환경 전반에서 공통으로 사용하는 변수 정의
# - 예:
#   - postgres_db_name
#   - vpn_cidr
#   - 포트 번호
#
# ⚠️ 주의
# - 계정 이름, 비밀번호, 토큰 등 비밀 정보는 저장하지 않음
#
# ==========================================================
# playbooks/site.yml
# ==========================================================
#
# 전체 자동화의 진입점(Entry Point)
#
# 실행 흐름:
# 1. PostgreSQL 설치
# 2. DB 스키마 및 테이블 생성 (DDL)
# 3. ROLE 및 권한 적용 (DCL)
# 4. 애플리케이션 배포
#
# ==========================================================
# playbooks/database
# ==========================================================
#
# install_postgres.yml
# - PostgreSQL 패키지 설치
# - 서비스 초기화
#
# init_schema.yml
# - IAM / Finance / Audit 스키마 생성
# - 테이블, 제약조건 등 DDL 적용
#
# apply_roles.yml
# - NOLOGIN ROLE 생성
# - GRANT / DEFAULT PRIVILEGES 적용
#
# ⚠️ SQL 파일에는 DB 계정/비밀번호가 포함되지 않음
#
# ==========================================================
# roles/postgres
# ==========================================================
#
# tasks/install.yml
# - PostgreSQL 설치 작업
#
# tasks/init.yml
# - DB 기본 초기화 작업
#
# tasks/roles.yml
# - LOGIN 가능한 DB USER 생성
# - 비밀번호는 설정하지 않음
#
# templates/postgresql.conf.j2
# - PostgreSQL 서버 동작 설정
# - listen_addresses
# - 로그 옵션
# - 성능 관련 기본 설정
#
# ==========================================================
# PostgreSQL 접근 제어 개요
# ==========================================================
#
# - 네트워크 접근:
#   - VPN 고정 CIDR만 허용
#
# - DB listen 범위:
#   - postgresql.conf 에서 제어
#
# - 인증/접근 제어:
#   - pg_hba.conf 에서 CIDR + 인증 방식 제어
#
# - 자동화 관리 작업:
#   - 로컬 소켓 + peer 인증
#
# ==========================================================
# 애플리케이션 roles
# ==========================================================
#
# ingest-service
# finance-rule-engine
# audit-writer
# iam-service
#
# 각 애플리케이션 role 구성:
#
# - tasks/main.yml
#   - Kubernetes 리소스 배포 트리거
#
# - k8s/
#   - Deployment / Service / ConfigMap 정의
#
# DB 접속 정보:
# - Kubernetes Secret으로 주입
# - Secret은 CI 또는 외부 Secret Manager에서 관리
#
# ==========================================================
# 보안 정책 요약
# ==========================================================
#
# - SQL에 계정/비밀번호 없음
# - Ansible 변수에 계정/비밀번호 없음
# - DB 접근은 다음 조합으로만 허용:
#   - VPN CIDR
#   - OS 사용자
#   - PostgreSQL ROLE
#
# - Audit 로그는 Append-only 설계
#
# ==========================================================
# 최종 정리
# ==========================================================
#
# 이 프로젝트는 다음을 목표로 합니다.
#
# - 온프레미스 환경에서의 안전한 자동화
# - DB 계정/비밀번호 없는 운영
# - 감사 및 규제 대응이 가능한 구조
# - 명확한 책임 분리와 유지보수성
#
# ==========================================================

