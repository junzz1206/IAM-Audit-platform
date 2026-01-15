## README - 테스트 방법

### 공통 준비물

* Terraform 버전: `terraform -version` 확인 (프로젝트 `versions.tf` 기준)
* AWS 자격증명: `aws configure` 또는 SSO/AssumeRole
* backend(S3/DynamoDB)가 있으면 `backend.tf` 값 확인(선구축 필요하면 선구축)
* 실행 위치: `envs/dev`

### 공통 실행 커맨드

cd envs/dev
terraform init -upgrade
terraform fmt -recursive
terraform validate
terraform plan -var-file="dev.tfvars"

---

# 1) “빈 계정(신규)” 테스트 플로우 (Greenfield)

목표: Terraform이 네트워크~EKS~IRSA~컨트롤러~ExternalDNS~Valkey~WireGuard~Failover까지 생성**하고, 마지막에 앱은 ArgoCD로 가는 구조 검증.

## Step 1. dev.tfvars 준비

* `create_certificate`를 어떻게 할지 결정

  * **권장(선구축 참조)**: `create_certificate=false` + `existing_certificate_arn` 입력
  * **신규 계정에서 Terraform 생성**: `create_certificate=true`
* WireGuard 민감값 채우기

  * `wg_private_key`, `onprem_peer_public_key`, `onprem_peer_endpoint`

## Step 2. Plan 확인

terraform plan -var-file="dev.tfvars"

확인 포인트:

* VPC/Subnet/RT/NAT 생성
* EKS cluster/nodegroup 생성
* OIDC provider 생성
* ALB Controller helm 설치
* ExternalDNS helm 설치
* Valkey 생성(Private subnet)
* WireGuard EC2 2대 + RT에 onprem route 반영
* Failover Lambda/Alarm 생성

## Step 3. Apply

terraform apply -var-file="dev.tfvars"

## Step 4. 기능 검증 체크리스트

### (A) EKS/컨트롤러

* `kubectl get nodes`
* `kubectl -n kube-system get deploy aws-load-balancer-controller`
* `kubectl -n kube-system get deploy external-dns`

### (B) ExternalDNS 동작

* (nginx ingress 하나 배포 후) Route53 레코드가 자동 생성되는지 확인
* ingress 삭제 시 upsert-only면 레코드가 “삭제되진 않음” (정책 의도 확인)

### (C) Valkey TLS

* Pod에서 `redis-cli --tls ping` → `PONG`

### (D) WireGuard 경유 On-Prem

* Private RT에 `192.168.1.0/24 -> (WG active ENI)` 잡혀있는지
* Pod에서 `nc -vz 192.168.1.151 5432` 성공

---

# 2) “기존 계정(리소스가 이미 있는 상태)” 테스트 플로우 (Brownfield)

목표: 이미 만들어진 환경을 Terraform state에 정확히 import해서 `plan 0 changes`에 최대한 가깝게 맞추는 것.

## 핵심 전략

1. “선구축 참조”는 **data로 조회**하고 모듈은 create를 끄거나(스위치) ARN/ID를 입력
2. “Terraform이 관리해야 하는 것”만 state에 import해서 drift를 없앰
3. `plan`에서 바뀌는 항목은 **원인(태그/이름/옵션)부터 동일화** 후 해결

## 권장 선구축/참조 영역(Plan 안정성 최우선)

* Route53 Hosted Zone (data 조회)
* ACM 인증서 (선구축 ARN 참조)
* (가능하면) 이미 운영 중인 ALB/WAF는 “생성 X, 참조만” 쪽으로 단계 분리 권장

  * 지금 구조상 ALB는 k8s ingress로 생기니까, WAF association은 추후 data로 연결하는 접근이 안정적

## Step 1. Import 먼저(대표 케이스)

### (A) OIDC Provider가 이미 존재하는 경우

네 모듈(eks)이 OIDC provider를 “항상 생성” 구조라면, 기존 계정에서 충돌 가능성이 있어.

* 이 경우 가장 안전한 건 OIDC provider를 import해서 state를 맞추는 것.

예시(네 state 주소는 실제 리소스명에 맞춰):

terraform import -var-file="dev.tfvars" module.eks.aws_iam_openid_connect_provider.this <OIDC_PROVIDER_ARN>

> OIDC가 “이미 있는데 Terraform도 만들려고 한다”면 거의 100% 여기서 걸림.
> import 후 plan에서 “새로 만들기”가 사라지는지 확인.

### (B) 이미 존재하는 리소스도 Terraform이 관리 대상으로 삼았으면 동일하게 import

예: VPC, Subnet, RouteTable, NATGW, EKS Cluster, NodeGroup, Valkey, WireGuard EC2/EIP 등
(리소스 주소는 `terraform state list`로 확인해서 맞춰야 함)

## Step 2. Plan으로 Drift 확인

terraform plan -var-file="dev.tfvars"

* 바뀌는 항목이 있으면:

  * “이름/태그/옵션 값”이 콘솔과 다르거나
  * 모듈 기본값이 콘솔 설정과 다르거나
  * AWS가 자동으로 채우는 속성을 코드에서 강제하고 있거나
  * 이미 존재하는데 “create=true”로 되어 있는 경우

## Step 3. 목표: plan 0 changes에 가까워지기 위한 조정 순서

1. input 변수/태그/이름(prefix)부터 동일화
2. 리소스별 `ignore_changes`는 최후의 수단(정말 drift가 의미 없을 때만)
3. “생성/참조 스위치”가 있는 모듈은 기존 계정에서는 참조 모드 우선

---

## 실행자가 실제로 치는 커맨드(표준)

terraform init -upgrade
terraform validate
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"