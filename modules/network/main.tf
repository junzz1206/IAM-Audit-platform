data "aws_region" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.env}"
  region      = data.aws_region.current.name
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# Public subnets
resource "aws_subnet" "public" {
  for_each = { for idx, s in var.public_subnets : idx => s }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = "${local.region}${each.value.az_suffix}"
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                     = "${local.name_prefix}-public-${each.value.az_suffix}"
    "kubernetes.io/role/elb"  = "1"
  })
}

# Private subnets
resource "aws_subnet" "private" {
  for_each = { for idx, s in var.private_subnets : idx => s }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = "${local.region}${each.value.az_suffix}"
  

  tags = merge(var.tags, {
    Name                              = "${local.name_prefix}-private-${each.value.az_suffix}"
    "kubernetes.io/role/internal-elb"  = "1"
  })
}

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-rt-public"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# NAT
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-nat-eip"
  })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = values(aws_subnet.public)[0].id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-natgw"
  })

  depends_on = [aws_internet_gateway.this]
}

# Private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-rt-private"
  })
}

resource "aws_route" "private_internet" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
