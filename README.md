---

# 🛡️ IAM Audit Platform

금융 보안 규정 준수를 위한 AWS-OnPremise 하이브리드 클라우드 구축 프로젝트

본 레포지토리는 법인카드 거래 데이터의 안전한 관리와 망 분리 요건을 충족하기 위한 하이브리드 인프라의 모든 소스 코드와 설계 명세를 담고 있는 마스터 아카이브입니다.

---

## 🎯 1. 프로젝트 설계 철학 (Design Philosophy)

단순한 기능 구현을 넘어, 실제 금융권의 제약 사항을 기술적으로 해결하는 데 집중했습니다.

Platform-First: 애플리케이션 기능보다 인프라의 구조적 완성도와 보안성을 우선합니다.
Data Sovereignty: 민감한 금융 데이터(PostgreSQL)는 온프레미스에 격리하여 데이터 주권을 확보합니다.
Hybrid Connectivity: AWS 클라우드의 유연성과 온프레미스의 보안성을 WireGuard VPN으로 안전하게 결합합니다.
Zero Trust: 모든 통신 구간은 암호화하며, 최소 권한 원칙에 기반한 네트워크 정책을 적용합니다.

---

## 🛠️ 2. 기술 스택 (Tech Stack)

| 분류 | 상세 기술 |
| --- | --- |
| Infrastructure | Terraform (IaC), AWS VPC, EKS (Elastic Kubernetes Service) |
| On-Premise | Rocky Linux 9, Mini PC Server |
| Database | PostgreSQL (On-Premise), ElastiCache Redis (AWS) |
| Networking | WireGuard VPN (Site-to-Site), AWS ALB |
| Observability | Prometheus, Loki, Grafana Stack |
| CI/CD | GitHub Actions, GitOps (ArgoCD 예정) |

---

## 📂 3. 디렉토리 구조 (A to Z Guide)

각 폴더는 독립적인 모듈로 작동하며, 전체 시스템을 재구축할 수 있는 가이드 역할을 합니다.

```text
IAM-Audit-platform/
├── infra/                  # [IaC] 인프라 자동화 코드
│   └── terraform/
│       ├── modules/        # VPC, EKS, VPN, SG 등 재사용 모듈
│       └── environments/   # dev/prod 환경별 실행 파일
├── app/                    # [Service] 법인카드 서비스 애플리케이션
│   ├── src/                # 백엔드/프론트엔드 소스
│   └── Dockerfile          # 컨테이너 빌드 명세
├── database/               # [Data] 온프레미스 DB 관리
│   ├── schema/             # DDL/DML SQL 스크립트
│   └── postgresql-conf/    # DB 최적화 및 보안 설정
├── monitoring/             # [Observability] 관제 시스템 설정
│   └── grafana/            # 대시보드 JSON 템플릿
├── docs/                   # [Docs] 설계서 및 아키텍처 다이어그램
└── README.md               # 프로젝트 마스터 가이드

```

---

## 🚀 4. 단계별 구축 가이드 (Deployment Steps)

### Phase 1: AWS 기반 인프라 구축

1. `infra/terraform/environments/dev` 이동
2. `terraform init` 및 `terraform apply` 실행
3. 생성 자원: VPC(), EKS Cluster, VPN EC2 Instance

### Phase 2: 하이브리드 연결 (VPN)

1. AWS 측 VPN 서버와 온프레미스 Rocky Linux 간 WireGuard 터널링 설정
2. **ChaCha20-Poly1305** 알고리즘을 통한 구간 암호화 확인
3. 온프레미스 DB 대역() 라우팅 전파

### Phase 3: 데이터베이스 및 앱 배포

1. 온프레미스 PostgreSQL 스키마 생성 및 접근 제어 설정
2. EKS 워커 노드에서 온프레미스 DB 연결성 테스트
3. 애플리케이션 컨테이너 배포 및 ALB 연동

---

## 👥 5. 팀원 및 역할 (R&R)

| 이름 | 역할 | 핵심 담당 업무 |
| --- | --- | --- |
| 이상준 (Team Lead) | **PM / Architect** | 전체 네트워크 아키텍처 설계, Terraform 인프라 구축, VPN 터널링 |
| 김창훈 | Infra Engineer | EKS 클러스터 최적화, 워커 노드 그룹 관리, 자원 스케일링 설정 |
| 이해빈 | S/W Developer | 법인카드 서비스 로직 개발, API 설계, DB 연동 및 쿼리 최적화 |
| 김성민 | System Admin | 온프레미스 서버 환경 구성, PostgreSQL 튜닝, 하드웨어 보안 강화 |
| 임지애 | DevOps Engineer | CI/CD 파이프라인 구축, 통합 모니터링(Grafana) 대시보드 구성 |

---

## 📈 6. 로드맵 (Roadmap)

 [x] 프로젝트 아키텍처 설계 및 네트워크 상세 명세 확정
 [x] IaC 기반 기본 VPC 및 서브넷 환경 구축
 [ ] WireGuard VPN을 통한 하이브리드 환경 통신 성공
 [ ] EKS 기반 서비스 배포 및 자동 확장(HPA) 테스트
 [ ] 하이브리드 통합 관제 대시보드 완성

---
<img width="1250" height="2001" alt="image" src="https://github.com/user-attachments/assets/f9c54b97-b544-4cda-865d-cf31a29100e5" />
