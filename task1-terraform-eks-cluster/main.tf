data "aws_vpc" "opsfleet-vpc" {
  id = var.vpc_id
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_eip" "eks_eip" {
  vpc = true

}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = data.aws_vpc.opsfleet-vpc.id
  tags = {
    Name = "opsfleet-igw"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  subnet_id     = aws_subnet.opsfleet-public-subnet-1.id
  allocation_id = aws_eip.eks_eip.id
  tags = {
    Name = "opsfleet-nat"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = data.aws_vpc.opsfleet-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "opsfleet-public-rtb"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = data.aws_vpc.opsfleet-vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name = "opsfleet-private-rtb"
  }
}


resource "aws_subnet" "opsfleet-public-subnet-1" {
  vpc_id            = data.aws_vpc.opsfleet-vpc.id
  availability_zone = "us-east-1a"
  cidr_block        = cidrsubnet(data.aws_vpc.opsfleet-vpc.cidr_block, 8, 0)
  tags = {
    Name = "opsfleet-public-subnet-1"
  }
}

resource "aws_subnet" "opsfleet-public-subnet-2" {
  vpc_id            = data.aws_vpc.opsfleet-vpc.id
  availability_zone = "us-east-1b"
  cidr_block        = cidrsubnet(data.aws_vpc.opsfleet-vpc.cidr_block, 8, 1)
  tags = {
    Name = "opsfleet-public-subnet-2"
  }
}

resource "aws_subnet" "opsfleet-private-subnet-1" {
  vpc_id            = data.aws_vpc.opsfleet-vpc.id
  availability_zone = "us-east-1a"
  cidr_block        = cidrsubnet(data.aws_vpc.opsfleet-vpc.cidr_block, 8, 2)
  tags = {
    Name = "opsfleet-private-subnet-1"
  }
}

resource "aws_subnet" "opsfleet-private-subnet-2" {
  vpc_id            = data.aws_vpc.opsfleet-vpc.id
  availability_zone = "us-east-1b"
  cidr_block        = cidrsubnet(data.aws_vpc.opsfleet-vpc.cidr_block, 8, 3)
  tags = {
    Name = "opsfleet-private-subnet-2"
  }
}

resource "aws_route_table_association" "backend_public_route_table_association_a" {
  subnet_id      = aws_subnet.opsfleet-public-subnet-1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_route_table_association_b" {
  subnet_id      = aws_subnet.opsfleet-public-subnet-2.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_route_table_association_a" {
  subnet_id      = aws_subnet.opsfleet-private-subnet-1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_route_table_association_b" {
  subnet_id      = aws_subnet.opsfleet-private-subnet-2.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_iam_role" "eks_cluster_iam" {
  name               = "eks-cluster-eks-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
  tags = {
    Name = "opsfleet-eks-cluster-iam-role"
  }
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_iam.name
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_iam.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.opsfleet-private-subnet-1.id,
      aws_subnet.opsfleet-private-subnet-2.id,
      aws_subnet.opsfleet-public-subnet-1.id,
      aws_subnet.opsfleet-public-subnet-2.id
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
  ]

  tags = {
    Name = "opsfleet-eks-cluster"
  }
}

resource "aws_iam_role" "eks_ng_iam" {
  name               = "eks-cluster-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags = {
    Name = "opsfleet-eks-nodegroup-iam-role"
  }
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_ng_iam.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_ng_iam.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_ng_iam.name
}

resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.eks_ng_iam.arn
  subnet_ids = [
    aws_subnet.opsfleet-private-subnet-1.id,
    aws_subnet.opsfleet-private-subnet-2.id
  ]

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  update_config {
    max_unavailable = var.max_unavailable
  }
  instance_types = var.instance_types
  disk_size      = var.disk_size

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = {
    Name = "opsfleet-nodegroup"
  }
}


data "tls_certificate" "opsfleet-cert" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "opsfleet-oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.opsfleet-cert.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}


data "aws_iam_policy_document" "opsfleet_oidc_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"


    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.opsfleet-oidc.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }


    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.opsfleet-oidc.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:*:${var.service_account_name}"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.opsfleet-oidc.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "opsfleet-oidc" {
  assume_role_policy = data.aws_iam_policy_document.opsfleet_oidc_assume_role_policy.json
  name               = "opsfleet-oidc"
}

resource "aws_iam_policy" "opsfleet-s3-policy" {
  name = "opsfleet-s3-policy"

  policy = jsonencode({
    Statement = [{
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ]
      Effect   = "Allow"
      Resource = "arn:aws:s3:::*"
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "opsfleet_oidc_attach" {
  role       = aws_iam_role.opsfleet-oidc.name
  policy_arn = aws_iam_policy.opsfleet-s3-policy.arn
}


output "oidc_policy_arn" {
  value = aws_iam_role.opsfleet-oidc.arn
}
