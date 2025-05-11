provider "aws" {
  region = "us-east-1"
  access_key= "AKIA3VO64NQEFR2SVSVG"
  secret_key= "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"
}


resource "aws_vpc" "bankapp_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "bankapp-vpc"
  }
}

resource "aws_subnet" "bankapp_subnet" {
  count = 2
  vpc_id                  = aws_vpc.bankapp_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.bankapp_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["us-east-1a", "us-east-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "bankapp-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "bankapp_igw" {
  vpc_id = aws_vpc.bankapp_vpc.id

  tags = {
    Name = "bankapp-igw"
  }
}

resource "aws_route_table" "bankapp_route_table" {
  vpc_id = aws_vpc.bankapp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bankapp_igw.id
  }

  tags = {
    Name = "bankapp-route-table"
  }
}

resource "aws_route_table_association" "bankapp_association" {
  count          = 2
  subnet_id      = aws_subnet.bankapp_subnet[count.index].id
  route_table_id = aws_route_table.bankapp_route_table.id
}

resource "aws_security_group" "bankapp_cluster_sg" {
  vpc_id = aws_vpc.bankapp_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bankapp-cluster-sg"
  }
}

resource "aws_security_group" "bankapp_node_sg" {
  vpc_id = aws_vpc.bankapp_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bankapp-node-sg"
  }
}

resource "aws_eks_cluster" "bankapp" {
  name     = "bankapp-cluster"
  role_arn = aws_iam_role.bankapp_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.bankapp_subnet[*].id
    security_group_ids = [aws_security_group.bankapp_cluster_sg.id]
  }
}


resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name    = aws_eks_cluster.bankapp.name
  addon_name      = "aws-ebs-csi-driver"
  
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}


resource "aws_eks_node_group" "bankapp" {
  cluster_name    = aws_eks_cluster.bankapp.name
  node_group_name = "bankapp-node-group"
  node_role_arn   = aws_iam_role.bankapp_node_group_role.arn
  subnet_ids      = aws_subnet.bankapp_subnet[*].id

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 2
  }

  instance_types = ["t2.small"]

  remote_access {
    ec2_ssh_key = var.ssh_key_name
    source_security_group_ids = [aws_security_group.bankapp_node_sg.id]
  }
}

resource "aws_iam_role" "bankapp_cluster_role" {
  name = "bankapp-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "bankapp_cluster_role_policy" {
  role       = aws_iam_role.bankapp_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "bankapp_node_group_role" {
  name = "bankapp-node-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "bankapp_node_group_role_policy" {
  role       = aws_iam_role.bankapp_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "bankapp_node_group_cni_policy" {
  role       = aws_iam_role.bankapp_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "bankapp_node_group_registry_policy" {
  role       = aws_iam_role.bankapp_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "bankapp_node_group_ebs_policy" {
  role       = aws_iam_role.bankapp_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
