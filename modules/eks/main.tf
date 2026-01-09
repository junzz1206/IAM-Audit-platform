# IAM Role – EKS Cluster
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-${var.env}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS Cluster (Public & Private Endpoint)
resource "aws_eks_cluster" "this" {
  name     = "${var.project_name}-${var.env}-eks"
  version  = var.eks_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = var.admin_cidr_blocks
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env}-eks"
  })

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# IAM Role – NodeGroup 공통
resource "aws_iam_role" "eks_node" {
  name = "${var.project_name}-${var.env}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ])

  role       = aws_iam_role.eks_node.name
  policy_arn = each.value
}

# NodeGroup – Admin UI
resource "aws_eks_node_group" "ui" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "ng-ui"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }

  labels = {
    workload = "ui"
  }

  tags = merge(var.tags, {
    Name = "ng-ui"
  })
}

# NodeGroup – IAM API (WireGuard 통과 주체)
resource "aws_eks_node_group" "iam" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "ng-iam"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }

  labels = {
    workload = "iam"
  }

  tags = merge(var.tags, {
    Name = "ng-iam"
  })
}
