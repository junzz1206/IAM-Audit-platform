#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# Root guard
# --------------------------------------------------
if [[ ${EUID:-9999} -ne 0 ]]; then
  echo "❌ root로 실행 필요 (sudo ./run-all.k8s.sh)"
  exit 1
fi

echo "=================================================="
echo " K8s 전체 실행 스크립트 (kubectl-only 최종본)"
echo " - Namespace / NFS / Monitoring / Apps"
echo " - Image Build + containerd import"
echo "=================================================="

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
K8S_DIR="$PROJECT_ROOT/k8s"
TMP_DIR="/var/tmp/k8s-images"

TAG="0.1.0-onprem"
CTR_NS="k8s.io"

mkdir -p "$TMP_DIR"

IMAGES=(
  iam-service
  audit-writer
  audit-relay
  audit-reader
  audit-query-api
  finance-rule-engine
  ingest-service
)

# --------------------------------------------------
# 사전 체크
# --------------------------------------------------
command -v kubectl >/dev/null || { echo "❌ kubectl 없음"; exit 1; }
command -v podman  >/dev/null || { echo "❌ podman 없음"; exit 1; }
command -v ctr     >/dev/null || { echo "❌ ctr 없음"; exit 1; }

kubectl get nodes >/dev/null 2>&1 || {
  echo "❌ kubeconfig 연결 실패"
  exit 1
}

# --------------------------------------------------
# util
# --------------------------------------------------
die() { echo "❌ $*"; exit 1; }

require_path() {
  [[ -e "$1" ]] || die "필수 경로 없음: $1"
}

reject_unrendered_template() {
  local p="$1"
  if grep -RIn -- '{{[^}]*}}' "$p" >/dev/null 2>&1; then
    die "템플릿 토큰({{ }}) 남아있음: $p (Ansible/Helm 렌더링 없이 apply 불가)"
  fi
}

apply_if_exists() {
  local p="$1"
  if [[ -e "$p" ]]; then
    kubectl apply -f "$p"
  fi
}

apply_dir_if_exists() {
  local d="$1"
  if [[ -d "$d" ]]; then
    kubectl apply -f "$d"
  fi
}

rollout_wait() {
  local ns="$1"
  local name="$2"
  if kubectl get deploy -n "$ns" "$name" >/dev/null 2>&1; then
    kubectl rollout status -n "$ns" deploy/"$name" --timeout=300s || true
  fi
}

# --------------------------------------------------
# 1. 커널 옵션
# --------------------------------------------------
echo "[1] net.ipv4.ip_forward"
sysctl -w net.ipv4.ip_forward=1 >/dev/null

# --------------------------------------------------
# 2. Calico 확인
# --------------------------------------------------
echo "[2] Calico 확인"
kubectl get pods -n kube-system | grep -q calico-node \
  || die "Calico 미설치/미정상 (calico-node 없음)"

# --------------------------------------------------
# 3. Namespace
# --------------------------------------------------
echo "[3] Namespace"
require_path "$K8S_DIR/namespaces.yml"
reject_unrendered_template "$K8S_DIR/namespaces.yml"
kubectl apply -f "$K8S_DIR/namespaces.yml"

# --------------------------------------------------
# 4. NFS PV / PVC  (✅ 최신 구조 기준)
# --------------------------------------------------
echo "[4] NFS PV/PVC"
require_path "$K8S_DIR/nfs/pv.yml"
require_path "$K8S_DIR/nfs/pvc.yml"
reject_unrendered_template "$K8S_DIR/nfs/pv.yml"
reject_unrendered_template "$K8S_DIR/nfs/pvc.yml"
kubectl apply -f "$K8S_DIR/nfs/pv.yml"
kubectl apply -f "$K8S_DIR/nfs/pvc.yml"

# --------------------------------------------------
# 5. 이미지 빌드
# --------------------------------------------------
echo "[5] Image build"
for img in "${IMAGES[@]}"; do
  require_path "$K8S_DIR/$img/Dockerfile"
  podman build -t "localhost/$img:$TAG" "$K8S_DIR/$img"
done

# --------------------------------------------------
# 6. containerd import
# --------------------------------------------------
echo "[6] containerd import"
for img in "${IMAGES[@]}"; do
  podman save --format oci-archive \
    "localhost/$img:$TAG" -o "$TMP_DIR/$img.tar"
  ctr -n "$CTR_NS" images import "$TMP_DIR/$img.tar"
done

# --------------------------------------------------
# 7. Monitoring (✅ k8s/monitoring 기준)
# --------------------------------------------------
echo "[7] Monitoring deploy"

# node-exporter: daemonset + service
apply_dir_if_exists "$K8S_DIR/monitoring/node-exporter"

# postgres-exporter: secret -> deployment -> service
apply_if_exists "$K8S_DIR/monitoring/postgres-exporter/secret.yml"
apply_if_exists "$K8S_DIR/monitoring/postgres-exporter/deployment.yml"
apply_if_exists "$K8S_DIR/monitoring/postgres-exporter/service.yml"

# --------------------------------------------------
# 8. 공통 ConfigMap/Secret 선적용 (🔥 여기 중요)
#    - finance 공통, audit 공통 같은 "앱들이 참조하는 cm/secret" 먼저
# --------------------------------------------------
echo "[8] Common ConfigMap/Secret (pre-apply)"

apply_dir_if_exists "$K8S_DIR/common"
apply_dir_if_exists "$K8S_DIR/audit-common"

# --------------------------------------------------
# 9. App ConfigMap/Secret
# --------------------------------------------------
echo "[9] App ConfigMap/Secret"
for app in "${IMAGES[@]}"; do
  apply_if_exists "$K8S_DIR/$app/configmap.yml"
  apply_if_exists "$K8S_DIR/$app/secret.yml"
done

# --------------------------------------------------
# 10. App Deploy (서비스/SA 포함 폴더 단위)
# --------------------------------------------------
echo "[10] App Deploy"
for app in "${IMAGES[@]}"; do
  reject_unrendered_template "$K8S_DIR/$app" || true
  kubectl apply -f "$K8S_DIR/$app"
done

# --------------------------------------------------
# 11. Rollout
# --------------------------------------------------
echo "[11] Rollout wait"

rollout_wait onprem-iam  iam-service
rollout_wait onprem-apps finance-rule-engine
rollout_wait onprem-apps ingest-service
rollout_wait onprem-apps audit-writer
rollout_wait onprem-audit audit-relay
rollout_wait onprem-audit audit-reader
rollout_wait onprem-audit audit-query-api

# --------------------------------------------------
echo "=================================================="
echo " 완료"
kubectl get pods -A
echo "=================================================="

