data "http" "my_public_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  detected_public_ip = trimspace(data.http.my_public_ip.response_body)

  base_admin_cidrs = length(var.admin_cidr_blocks) > 0 ? var.admin_cidr_blocks : [
    "${local.detected_public_ip}/32"
  ]

  effective_admin_cidrs = distinct(
    concat(
      local.base_admin_cidrs,
      var.extra_admin_cidrs
    )
  )
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# network
module "network" {
  source = "../../modules/network"

  project_name = var.project_name
  env          = var.env

  vpc_cidr = "10.100.0.0/16"

  public_subnets = [
    { cidr = "10.100.1.0/24", az_suffix = "a" },
    { cidr = "10.100.2.0/24", az_suffix = "c" }
  ]

  private_subnets = [
    { cidr = "10.100.10.0/24", az_suffix = "a" },
    { cidr = "10.100.11.0/24", az_suffix = "c" }
  ]

  tags = {
    Project   = var.project_name
    Env       = var.env
    ManagedBy = "Terraform"
    Owner     = "CloudInfra"
  }
}

# eks
module "eks" {
  source = "../../modules/eks"

  project_name = var.project_name
  env          = var.env

  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  admin_cidr_blocks = local.effective_admin_cidrs

  tags = {
    Project   = var.project_name
    Env       = var.env
    ManagedBy = "Terraform"
    Owner     = "CloudInfra"
  }
}

# IRSA
module "irsa" {
  source = "../../modules/IRSA"

  project_name      = var.project_name
  env               = var.env
  eks_cluster_name  = module.eks.cluster_name

  tags = {
    Project   = var.project_name
    Env       = var.env
    ManagedBy = "Terraform"
    Owner     = "CloudInfra"
  }
}

# k8s_namespaces
module "k8s_namespaces_v1" {
  source = "../../modules/k8s-namespaces"

  providers = {
    kubernetes = kubernetes.eks
  }

  project_name = var.project_name
  env          = var.env

  namespaces = [
    "admin-ui",
    "iam-api"
  ]

  extra_labels = {
    managed_by = "Terraform"
  }
}

# wireguard (EIP + RouteTable ENI 대상)
module "wireguard_ha" {
  source = "../../modules/wireguard"

  name_prefix = var.project_name
  env = var.env

  tags = {
    ManagedBy = "Terraform"
    Owner     = "CloudInfra"
  }

  vpc_id                = module.network.vpc_id
  public_subnet_ids      = module.network.public_subnet_ids
  private_route_table_id = module.network.private_route_table_id

  onprem_cidr = var.onprem_cidr
  admin_cidrs = local.effective_admin_cidrs

  wireguard_allowed_cidrs = var.wireguard_allowed_cidrs

  wg_addresses = var.wg_addresses

  ami_id = data.aws_ami.amazon_linux_2.id
}

# wg_failover (Active 장애 -> Standby로 EIP+Route 이동)
module "wg_failover" {
  source = "../../modules/wg_failover"

  name_prefix = var.project_name
  env = var.env

  tags = {
    ManagedBy = "Terraform"
    Owner     = "CloudInfra"
  }

  active_instance_id = module.wireguard_ha.active_instance_id

  eip_allocation_id = module.wireguard_ha.eip_allocation_id
  route_table_id    = module.network.private_route_table_id
  dest_cidr         = var.onprem_cidr

  standby_eni_id = module.wireguard_ha.standby_eni_id
}

# valkey
module "valkey" {
  source = "../../modules/cache_valkey"

  name_prefix = var.project_name
  env         = var.env
  
  tags = {
    ManagedBy = "Terraform"
    Owner     = "CloudInfra"
  }

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids

  # 중요: EKS 모듈에서 이 output이 나와야 함
  eks_worker_sg_id = module.eks.cluster_security_group_id

  # 아래는 tfvars로 조절 가능
  engine_version          = var.valkey_engine_version
  node_type               = var.valkey_node_type
  num_node_groups         = var.valkey_num_node_groups
  replicas_per_node_group = var.valkey_replicas_per_node_group
  parameter_group_name    = var.valkey_parameter_group_name
  snapshot_retention_days = var.valkey_snapshot_retention_days
  auto_minor_version_upgrade = var.valkey_auto_minor_version_upgrade
}

# alb_controller
module "alb_controller" {
  source = "../../modules/alb_controller"

  project_name       = var.project_name
  env                = var.env
  region             = var.region
  tags               = var.tags

  cluster_name       = module.eks.cluster_name
  vpc_id             = module.vpc.vpc_id

  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_issuer_url    = module.eks.oidc_issuer_url

  # dev는 고정 추천 (예: "1.?.?")
  helm_chart_version = var.alb_controller_chart_version
}


# route53_externaldns
module "route53_externaldns" {
  source = "./modules/route53_externaldns"

  cluster_name              = module.eks.cluster_name
  region                    = var.region

  domain_name               = "rockyvicky.com"
  create_hosted_zone        = false
  hosted_zone_id            = var.hosted_zone_id

  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
  cluster_oidc_issuer_url   = module.eks.oidc_issuer_url

  txt_owner_id              = "rockyvicky-dev"
  policy                    = "upsert-only" # 운영 안전 우선이면 upsert-only 추천

  tags = var.tags
}

# acm_cert
module "acm" {
  source = "./modules/acm_cert"

  domain_name     = "rockyvicky.com"
  hosted_zone_id  = "Z026212028803MNA1UOL0"

  # 기본: apex + wildcard 1장
  create_wildcard = true

  # 보통 wildcard면 api/admin 포함되니 굳이 안 넣어도 됨
  additional_sans = []

  tags = var.tags
}

# waf
module "waf" {
  source = "../../modules/waf"

  project_name = var.project_name
  env          = var.env

  # 처음엔 튜닝 목적 COUNT 추천 (지금 일정 촉박하면 특히)
  count_mode = true

  enable_logging       = false
  log_destination_arns = []

  tags = var.tags
}

# externaldns
module "externaldns" {
  source = "../../modules/externaldns"

  cluster_name = module.eks.cluster_name
  region       = var.aws_region
  vpc_id       = module.vpc.vpc_id

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.oidc_issuer_url

  hosted_zone_id = module.route53_externaldns.hosted_zone_id
  domain_filter  = "rockyvicky.com"

  txt_owner_id = var.externaldns_txt_owner_id
  policy       = var.externaldns_policy # "upsert-only" 추천(초기), 운영정리 원하면 "sync"
}
