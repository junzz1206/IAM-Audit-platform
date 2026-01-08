Audit Relay (PostgreSQL → OpenSearch)

개요

Audit Relay는 PostgreSQL에 적재된 감사(Audit) 로그를 OpenSearch로 Near Real-Time(NRT) 방식으로 동기화하는 워커 서비스이다.

본 시스템의 감사 로그 아키텍처는 다음 원칙을 따른다.

PostgreSQL

민감 데이터의 최종 원장(System of Record)

감사 로그의 무결성 및 법적 증적 책임

OpenSearch

감사 로그의 메인 조회소

검색, 알림, 대시보드, 보안 분석(SIEM) 용도

Audit Relay

DB → OpenSearch 비동기 전송 담당

애플리케이션과 완전히 분리된 독립 워커

OpenSearch 장애는 비즈니스 트랜잭션에 영향을 주지 않으며,
모든 감사 로그는 항상 DB에 먼저 기록된다.

전체 흐름

Application에서 비즈니스 트랜잭션 수행 시,
비즈니스 데이터와 audit.audit_events 테이블에 로그를 함께 INSERT하고 COMMIT한다.

PostgreSQL은 감사 로그의 기준 원장(System of Record) 역할을 수행한다.

Audit Relay는 PostgreSQL을 주기적으로 조회하여
아직 전송되지 않은 감사 로그를 OpenSearch로 비동기 전송한다.

OpenSearch는 감사 로그의 메인 조회 및 분석 시스템으로 사용된다.

주요 설계 특징

3.1 Near Real-Time (NRT)

Polling + Bulk Index 방식 사용

평균 지연 시간은 수백 밀리초에서 1초 이내

운영 및 알림 기준에서 실시간으로 인지 가능

3.2 멀티 워커 병렬 안전성

FOR UPDATE SKIP LOCKED 사용

여러 audit-relay 파드 동시 실행 가능

중복 처리 및 경합 발생 없음

3.3 Idempotent 처리

OpenSearch 문서 ID는 audit_id 사용

재전송 시 동일 문서를 덮어쓰기

중복 로그 생성 방지

3.4 장애 격리

OpenSearch 장애 발생 시에도 DB 트랜잭션은 정상 수행

감사 로그는 DB에 안전하게 누적

relay 복구 후 자동 재전송

디렉토리 구조

roles/audit-relay/

tasks/main.yml

k8s/deployment.yml

k8s/secret.yml

k8s/serviceaccount.yml

files/Dockerfile

files/audit_relay.py

README.md

환경 변수

Audit Relay는 모든 설정을 환경 변수로만 제어한다.

PG_DSN
PostgreSQL 접속 DSN

OS_HOST
OpenSearch 호스트 주소

OS_PORT
OpenSearch 포트

OS_INDEX
감사 로그 인덱스 이름

BATCH_SIZE
한 번에 처리할 audit 로그 개수

POLL_INTERVAL_SEC
Polling 주기 (NRT 동작 조절)

이미지 빌드

Docker Hub 계정은 필요하지 않다.
Audit Relay 이미지는 직접 빌드하여 사용한다.

이미지 빌드 위치:
roles/audit-relay/files

이미지 태그 예시:
audit-relay:1.0.0

Kubernetes 배포

Audit Relay 이미지는 Ansible 변수로 관리한다.

inventories/onprem/group_vars/all.yml 예시:

audit_relay_image: audit-relay:1.0.0

배포는 playbooks/site.yml 실행을 통해 수행된다.

운영 포인트

8.1 성능 튜닝

replicas 증가 시 처리량은 선형적으로 증가

POLL_INTERVAL_SEC 감소 시 지연 시간 감소

BATCH_SIZE 조절로 DB와 OpenSearch 부하 균형 조절

8.2 장애 대응

OpenSearch 장애 시 별도 운영 조치 불필요

relay 재기동 후 자동 재처리

audit.audit_events 테이블이 항상 기준 데이터

변경 이력 관리

이미지는 반드시 버전 태그로 관리한다.

내부 로직 수정: 1.0.1

포맷 또는 필드 변경: 1.1.0

구조 변경: 2.0.0

latest 태그 사용 금지.

요약

감사 로그의 기준은 항상 PostgreSQL

OpenSearch는 조회, 분석, 알림 담당

Audit Relay는 두 시스템을 안전하게 연결

NRT 방식은 타협이 아니라 운영을 위한 정석 설계
