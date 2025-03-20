provider "aws" {
  region = "ap-northeast-1"
}

# VPC設定 (既存のVPCを使用することも可能)
resource "aws_vpc" "eks_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "eks-vpc"
  }
}

# パブリックサブネット (2つの異なるAZ - EKSの要件)
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "eks-public-subnet-1"
    "kubernetes.io/cluster/fastapi-eks-cluster" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "eks-public-subnet-2"
    "kubernetes.io/cluster/fastapi-eks-cluster" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
}

# インターネットゲートウェイ
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks-igw"
  }
}

# パブリックルートテーブル
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "eks-public-rt"
  }
}

# パブリックルートテーブルの関連付け
resource "aws_route_table_association" "public_rt_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# EKSクラスター用IAMロール
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

# EKSクラスター用ポリシーアタッチメント
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# EKSノード用IAMロール
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# EKSノード用ポリシーアタッチメント
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_ecr_readonly_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
  role       = aws_iam_role.eks_node_role.name
}

# EKSクラスター作成 (簡易版)
resource "aws_eks_cluster" "fastapi_cluster" {
  name     = "fastapi-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.28"

  vpc_config {
    subnet_ids = [
      aws_subnet.public_subnet_1.id,
      aws_subnet.public_subnet_2.id
    ]
    endpoint_private_access = false
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# EKSノードグループ (簡易版)
resource "aws_eks_node_group" "fastapi_node_group" {
  cluster_name    = aws_eks_cluster.fastapi_cluster.name
  node_group_name = "fastapi-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]
  instance_types = ["t3.small"] # 小さいインスタンスタイプに変更

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_readonly_policy
  ]
}

# ECRリポジトリ
resource "aws_ecr_repository" "fastapi_app" {
  name                 = "fastapi-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# アウトプット
output "eks_cluster_endpoint" {
  value = aws_eks_cluster.fastapi_cluster.endpoint
}

output "eks_cluster_name" {
  value = aws_eks_cluster.fastapi_cluster.name
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ap-northeast-1 --name ${aws_eks_cluster.fastapi_cluster.name}"
}

output "ecr_repository_url" {
  value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.ap-northeast-1.amazonaws.com/fastapi-app"
}

# 現在のAWSアカウントID取得
data "aws_caller_identity" "current" {}
