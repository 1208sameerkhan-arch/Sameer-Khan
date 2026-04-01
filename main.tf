############################################
# PROVIDER
############################################

provider "aws" {
  region = "ap-south-1"
}

data "aws_availability_zones" "available" {}

############################################
# VPC
############################################

resource "aws_vpc" "fresh_vpc" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "fresh-eks-vpc" }
}

############################################
# INTERNET GATEWAY
############################################

resource "aws_internet_gateway" "fresh_igw" {
  vpc_id = aws_vpc.fresh_vpc.id
}

############################################
# PUBLIC SUBNETS
############################################

resource "aws_subnet" "fresh_public" {
  count                   = 2
  vpc_id                  = aws_vpc.fresh_vpc.id
  cidr_block              = "10.20.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "fresh-public-${count.index}" }
}

############################################
# PRIVATE SUBNETS
############################################

resource "aws_subnet" "fresh_private" {
  count             = 2
  vpc_id            = aws_vpc.fresh_vpc.id
  cidr_block        = "10.20.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "fresh-private-${count.index}" }
}

############################################
# PUBLIC ROUTE TABLE
############################################

resource "aws_route_table" "fresh_public_rt" {
  vpc_id = aws_vpc.fresh_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.fresh_igw.id
  }
}

resource "aws_route_table_association" "fresh_public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.fresh_public[count.index].id
  route_table_id = aws_route_table.fresh_public_rt.id
}

############################################
# NAT GATEWAY
############################################

resource "aws_eip" "fresh_nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "fresh_nat" {
  allocation_id = aws_eip.fresh_nat_eip.id
  subnet_id     = aws_subnet.fresh_public[0].id

  depends_on = [aws_internet_gateway.fresh_igw]
}

############################################
# PRIVATE ROUTE TABLE
############################################

resource "aws_route_table" "fresh_private_rt" {
  vpc_id = aws_vpc.fresh_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.fresh_nat.id
  }
}

resource "aws_route_table_association" "fresh_private_assoc" {
  count          = 2
  subnet_id      = aws_subnet.fresh_private[count.index].id
  route_table_id = aws_route_table.fresh_private_rt.id
}

############################################
# IAM ROLE FOR CLUSTER
############################################

resource "aws_iam_role" "fresh_cluster_role" {
  name = "fresh-eks-cluster-role-2026"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "fresh_cluster_policy" {
  role       = aws_iam_role.fresh_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

############################################
# EKS CLUSTER
############################################

resource "aws_eks_cluster" "fresh_cluster" {
  name     = "fresh-eks-cluster-2026"
  role_arn = aws_iam_role.fresh_cluster_role.arn

  vpc_config {
    subnet_ids = aws_subnet.fresh_private[*].id
  }

  depends_on = [aws_iam_role_policy_attachment.fresh_cluster_policy]
}

############################################
# IAM ROLE FOR NODE GROUP
############################################

resource "aws_iam_role" "fresh_node_role" {
  name = "fresh-eks-node-role-2026"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "fresh_worker_policy" {
  role       = aws_iam_role.fresh_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "fresh_cni_policy" {
  role       = aws_iam_role.fresh_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "fresh_registry_policy" {
  role       = aws_iam_role.fresh_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

############################################
# NODE GROUP
############################################

resource "aws_eks_node_group" "fresh_nodes" {
  cluster_name    = aws_eks_cluster.fresh_cluster.name
  node_group_name = "fresh-node-group-2026"
  node_role_arn   = aws_iam_role.fresh_node_role.arn
  subnet_ids      = aws_subnet.fresh_private[*].id

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 3
  }

  instance_types = ["t3.medium"]

  depends_on = [
    aws_eks_cluster.fresh_cluster,
    aws_nat_gateway.fresh_nat
  ]
}
