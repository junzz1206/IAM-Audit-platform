locals {
  common_tags = merge(var.tags, {
    Env       = var.env
    ManagedBy = "Terraform"
  })

  subnet_group_name = "${var.name_prefix}-${var.env}-valkey-subnet-group"
  sg_name           = "${var.name_prefix}-${var.env}-valkey-sg"
  rg_id             = "${var.name_prefix}-${var.env}-valkey-rg"
}

resource "aws_elasticache_subnet_group" "this" {
  name       = local.subnet_group_name
  subnet_ids = var.subnet_ids

  tags = merge(local.common_tags, {
    Name = local.subnet_group_name
  })
}

resource "aws_security_group" "this" {
  name        = local.sg_name
  description = "Valkey access only from EKS worker node SG"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Valkey from EKS worker SG only"
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    security_groups = [var.eks_worker_sg_id]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = local.sg_name
  })
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id    = local.rg_id
  description             = local.rg_id

  engine                  = "valkey"
  engine_version          = var.engine_version
  port                    = var.port
  node_type               = var.node_type

  # Cluster mode enabled(샤드/레플리카)
  num_node_groups         = var.num_node_groups
  replicas_per_node_group = var.replicas_per_node_group

  automatic_failover_enabled = true
  multi_az_enabled           = true

  subnet_group_name       = aws_elasticache_subnet_group.this.name
  security_group_ids      = [aws_security_group.this.id]
  parameter_group_name    = var.parameter_group_name

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  transit_encryption_mode = var.transit_encryption_mode

  snapshot_retention_limit    = var.snapshot_retention_days
  auto_minor_version_upgrade  = var.auto_minor_version_upgrade

  tags = merge(local.common_tags, {
    Name = local.rg_id
  })
}
