terraform {
  # backend는 backend.tf에서 관리
}

locals {
  base_tags = {
    Project   = var.project_name
    Env       = var.env
    ManagedBy = "Terraform"
    Owner     = "CloudInfra"
  }

  tags = merge(local.base_tags, var.tags)

  # network 서브넷 태그는 EKS 생성 전에 필요하므로 "고정 문자열"로 잡아야 cycle이 안 생김
  # 실제 클러스터명과 반드시 동일해야 함
  cluster_tag_name = var.eks_cluster_name

  azs = ["ap-northeast-2a", "ap-northeast-2c"]

  public_subnets = [
    {
      name = "public-a"
      cidr = var.public_subnet_cidrs[0]
      az   = local.azs[0]
      az_suffix = "a"
    },
    {
      name = "public-c"
      cidr = var.public_subnet_cidrs[1]
      az   = local.azs[1]
      az_suffix = "c"
    }
  ]

  private_subnets = [
    {
      name = "private-a"
      cidr = var.private_subnet_cidrs[0]
      az   = local.azs[0]
      az_suffix = "a"
    },
    {
      name = "private-c"
      cidr = var.private_subnet_cidrs[1]
      az   = local.azs[1]
      az_suffix = "c"
    }
  ]
}

# =========================================
# 1) Network (VPC/Subnet/RT/IGW/NAT + subnet tags)
# =========================================
module "network" {
  source = "../../modules/network"

  project_name = var.project_name
  env          = var.env

  vpc_cidr = var.vpc_cidr

  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets

  enable_nat_gateway = var.enable_nat_gateway

  # 중요: EKS 생성 전에 서브넷 태그가 필요함 (cycle 방지)
  cluster_tag_name = local.cluster_tag_name

  tags = local.tags
}

# =========================================
# 2) EKS (Cluster + NodeGroups + OIDC output)
# =========================================
module "eks" {
  source = "../../modules/eks"

  project_name = var.project_name
  env          = var.env

  cluster_name = var.eks_cluster_name
  eks_version  = var.eks_cluster_version

  vpc_id             = module.network.vpc_id
  private_subnet_ids  = module.network.private_subnet_ids

  node_groups        = var.eks_node_groups

  # EKS endpoint 접근 CIDR(있으면 권장)
  admin_cidr_blocks  = var.admin_cidr_blocks

  tags = local.tags
}

# =========================================
# 3) Route53 (Hosted Zone 조회 전용)
# =========================================
module "route53" {
  source = "../../modules/route53"

  domain_name  = var.domain_name
  private_zone = false
}

# =========================================
# 4) ACM (생성 모드 / 참조 모드 스위치)
# =========================================
module "acm" {
  source = "../../modules/acm"

  domain_name = var.domain_name

  create_certificate       = var.create_certificate
  existing_certificate_arn = var.existing_certificate_arn

  # create_certificate=true일 때만 필요
  hosted_zone_id = module.route53.hosted_zone_id

  create_wildcard = true

  tags = local.tags
}

# =========================================
# 5) AWS Load Balancer Controller (IRSA + Helm)
# =========================================
module "alb_controller" {
  source = "../../modules/alb-controller"

  project_name = var.project_name
  env          = var.env

  cluster_name = module.eks.cluster_name
  region       = var.aws_region

  vpc_id = module.network.vpc_id

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.oidc_issuer_url

  tags = local.tags

  # providers alias를 쓰는 모듈이라면 여기서 연결 (모듈 내부가 default provider만 쓰면 없어도 됨)
  # providers = {
  #   helm       = helm.eks
  #   kubernetes = kubernetes.eks
  # }
}

# =========================================
# 6) ExternalDNS (IRSA + Helm)
# =========================================
module "external_dns" {
  source = "../../modules/external-dns"

  providers = {
    kubernetes = kubernetes.eks
    helm       = helm.eks
  }

  project_name = var.project_name
  env          = var.env

  domain = var.domain_name

  hosted_zone_id = module.route53.hosted_zone_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.oidc_issuer_url

  txt_owner_id = var.txt_owner_id
  policy       = var.externaldns_policy

  tags = local.tags

  depends_on = [module.eks]

  # providers = {
  #   helm       = helm.eks
  #   kubernetes = kubernetes.eks
  # }
}

# =========================================
# 7) WAF (WebACL만 생성, ALB association은 추후 data/선구축 참조로)
# =========================================
module "waf" {
  source = "../../modules/waf"

  project_name = var.project_name
  env          = var.env

  count_mode = true
  tags       = local.tags

  # 지금 단계에서는 assoc/logging 끔 (의도 고정)
  associate_to_alb = false
  enable_logging   = false
}

# =========================================
# 8) Valkey (ElastiCache) - TLS only
# =========================================
module "valkey" {
  source = "../../modules/valkey"

  name_prefix     = "${var.project_name}-${var.env}"
  env              = var.env
  eks_worker_sg_id = module.eks.node_security_group_id

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids

  node_type = var.valkey_node_type

  num_node_groups           = var.valkey_num_node_groups
  replicas_per_node_group   = var.valkey_replicas_per_node_group

  transit_encryption_mode = "required"

  tags = local.tags
}

# =========================================
# 9) WireGuard (EC2 2대 + RouteTable 고정 라우트)
#    - drift 방지(ignore_changes) 이미 모듈에서 반영
# =========================================
module "wireguard" {
  source = "../../modules/wireguard"

  # wireguard 모듈이 요구하는 필수값
  name_prefix             = "${var.project_name}-${var.env}"
  env                     = var.env
  admin_cidrs             = var.admin_cidr_blocks
  wireguard_allowed_cidrs = var.wireguard_allowed_cidrs
  wg_addresses            = var.wg_addresses
  wg_private_key          = var.wg_private_key
  onprem_peer_public_key  = var.onprem_peer_public_key
  onprem_peer_endpoint    = var.onprem_peer_endpoint
  onprem_allowed_ips      = var.onprem_allowed_ips
  vpc_cidr                = var.vpc_cidr

  # 기존에 에러로 찍히지 않았던 값들은 유지(모듈이 받는 값일 가능성 높음)
  vpc_id                 = module.network.vpc_id
  public_subnet_ids      = module.network.public_subnet_ids
  private_route_table_id = module.network.private_route_table_id
  onprem_cidr            = var.onprem_cidr

  tags = local.tags
}

# =========================================
# 10) WG Failover (CloudWatch Alarm -> Lambda)
# =========================================
module "wg_failover" {
  source = "../../modules/wg_failover"

  name_prefix        = "${var.project_name}-${var.env}"
  env                 = var.env
  active_instance_id = module.wireguard.active_instance_id

  eip_allocation_id = module.wireguard.eip_allocation_id
  route_table_id    = module.network.private_route_table_id
  dest_cidr         = var.onprem_cidr
  standby_eni_id    = module.wireguard.standby_eni_id

  log_retention_days        = var.wg_failover_log_retention_days
  alarm_datapoints_to_alarm = var.wg_failover_datapoints_to_alarm

  tags = local.tags
}
