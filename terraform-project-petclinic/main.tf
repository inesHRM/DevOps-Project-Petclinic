################## VPC AND NETWORKING #############################
# Create a VPC
resource "aws_vpc" "petclinic_vpc" {
  cidr_block           = var.cidr_vpc
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "petclinic-vpc"
  }
}

# create two public subnets resources
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.petclinic_vpc.id
  cidr_block              = var.cidr_public_subnet_a
  map_public_ip_on_launch = "true"
  availability_zone       = var.az_a

  tags = {
    Name = "petclinic-public-subnet-a"
  }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.petclinic_vpc.id
  cidr_block              = var.cidr_public_subnet_b
  map_public_ip_on_launch = "true"
  availability_zone       = var.az_b

  tags = {
    Name = "petclinic-public-subnet-b"
  }
}

# create an internet gateway for our vpc
resource "aws_internet_gateway" "petclinic_internet_gateway" {
  vpc_id = aws_vpc.petclinic_vpc.id

  tags = {
    Name = "petclinic-internet-gateway"
  }
}

# create a route table for public subnets
resource "aws_route_table" "route_table_public" {
  vpc_id = aws_vpc.petclinic_vpc.id

  tags = {
    Name = "petclinic-public-route-table"
  }
}

# create a route to the internet gateway
resource "aws_route" "route_igw" {
  route_table_id         = aws_route_table.route_table_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.petclinic_internet_gateway.id
}

# Attach public subnet a to route table
resource "aws_route_table_association" "route_table_subnet_association_pub_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.route_table_public.id
}

# Attach public subnet b to route table
resource "aws_route_table_association" "rta_subnet_association_pubb" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.route_table_public.id
}

############### EKS CLUSTER #############################
# Create an EKS Cluster 
resource "aws_eks_cluster" "petclinic_eks_cluster" {
  name     = "petclinic-eks-cluster"
  role_arn = aws_iam_role.eks_iam_role.arn

  vpc_config {
    subnet_ids = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
  }

  depends_on = [
    aws_iam_role.eks_iam_role,
  ]
}

# IAM resource that ensures that the role has access to EKS
resource "aws_iam_role" "eks_iam_role" {
  name = "petclinic-eks-eks-iam-role"

  path = "/"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  tags = {
    name = "eks cluster iam role"
  }

}
# The two policies allow you to properly access EC2 instances (where the worker nodes run) and EKS.
resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_iam_role.name
}
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly-EKS" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_iam_role.name
}

# Create the worker nodes
resource "aws_eks_node_group" "worker-node-group" {
  cluster_name    = aws_eks_cluster.petclinic_eks_cluster.name
  node_group_name = "petclinic-workernodes"
  node_role_arn   = aws_iam_role.workernodes.arn
  subnet_ids      = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
  instance_types  = ["t3.large"]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}
# Create iam role and policies for our workrer nodes
resource "aws_iam_role" "workernodes" {
  name = "eks-node-group-1"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com",

      }

    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.workernodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.workernodes.name
}

resource "aws_iam_role_policy_attachment" "EC2InstanceProfileForImageBuilderECRContainerBuilds" {
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
  role       = aws_iam_role.workernodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.workernodes.name
}