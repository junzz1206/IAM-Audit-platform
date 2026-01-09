terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_region" "current" {}

# 최신 Amazon Linux 2023 AMI (ami_id 미지정 시)
data "aws_ssm_parameter" "al2023_ami" {
  count = var.ami_id == "" ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

locals {
  ami = var.ami_id != "" ? var.ami_id : data.aws_ssm_parameter.al2023_ami[0].value

  common_tags = merge(var.tags, {
    Env       = var.env
    ManagedBy = "Terraform"
  })
}

resource "aws_security_group" "wg" {
  name        = "${var.name_prefix}-${var.env}-wg-sg"
  description = "WireGuard VPN Gateway SG"
  vpc_id      = var.vpc_id

  # WireGuard UDP (제한 CIDR)
  ingress {
    description = "WireGuard"
    from_port   = var.wireguard_port
    to_port     = var.wireguard_port
    protocol    = "udp"
    cidr_blocks = var.wireguard_allowed_cidrs
  }

  # SSH (관리 IP만)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidrs
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-${var.env}-wg-sg"
  })
}

resource "aws_instance" "wg" {
  count         = 2
  ami           = local.ami
  instance_type = var.instance_type
  subnet_id     = var.public_subnet_ids[count.index]

  vpc_security_group_ids      = [aws_security_group.wg.id]
  associate_public_ip_address = true

  source_dest_check = false

  # user-data : WG_ADDRESS만 각 인스턴스별로 다르게 주입
  user_data = templatefile("${path.module}/userdata.sh.tpl", {
    wg_address = var.wg_addresses[count.index]
    wg_port    = var.wireguard_port
  })

  tags = merge(local.common_tags, {
    Name  = "${var.name_prefix}-${var.env}-wg-${count.index == 0 ? "active" : "standby"}"
    Role  = count.index == 0 ? "wg-active" : "wg-standby"
  })
}

# EIP 1개 (단일 엔드포인트)
resource "aws_eip" "wg" {
  domain = "vpc"
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-${var.env}-wg-eip"
  })
}

# EIP를 Active 인스턴스의 Primary ENI에 연결 (초기 Active)
resource "aws_eip_association" "wg" {
  allocation_id        = aws_eip.wg.allocation_id
  network_interface_id = aws_instance.wg[0].primary_network_interface_id
}

# Private RT에 온프렘 CIDR 라우트 추가 (초기 Active ENI로)
resource "aws_route" "to_onprem" {
  route_table_id         = var.private_route_table_id
  destination_cidr_block = var.onprem_cidr
  network_interface_id   = aws_instance.wg[0].primary_network_interface_id
}
