provider "aws" {
region = "us-east-1"    
}


resource "aws_vpc" "main" {           
  cidr_block = "10.0.0.0/16" 
  enable_dns_support   = true 
  enable_dns_hostnames = true  

  tags = {
    Name = "MainVPC"
  }
}

resource "aws_subnet" "public_subnet_1" {   
  vpc_id                  = aws_vpc.main.id     
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"  

  tags = {
    Name = "PublicSubnet1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"

  tags = {
    Name = "PublicSubnet2"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "MainIGW"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

resource "aws_route_table_association" "subnet_1_assoc" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "subnet_2_assoc" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "eks-sg" {
  name        = "eks"
  description = "Allow inbound and outbound traffic"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "eks_sg"
  }
 

  dynamic "ingress" {
    iterator = port
    for_each = var.ingress-rules
    content {
         description      = "Inbound Rules"
         from_port        = port.value
         to_port          = port.value
         protocol         = "TCP"
         cidr_blocks      = ["0.0.0.0/0"] 
    }
  }

 dynamic "egress" {
    iterator = port
    for_each = var.egress-rules
    content {
         description      = "outbound Rules"
         from_port        = port.value
         to_port          = port.value
         protocol         = "TCP"
         cidr_blocks      = ["0.0.0.0/0"] 
    }
  }
}	

# Create IAM role with assume role policy for EKS cluster
resource "aws_iam_role" "eks_cluster_role" {
  name               = "eks-cluster-role" 
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "eks.amazonaws.com"  
        }
      }
    ]
  })
}

# Attach AmazonEKSClusterPolicy to the EKS role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count = length(var.eks_cluster_policies)
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = var.eks_cluster_policies[count.index]
}


resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn 
  version = "1.32"

  vpc_config {
    subnet_ids         = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
    security_group_ids = [aws_security_group.eks-sg.id] 
    endpoint_private_access = true
    endpoint_public_access  = true
    }
     depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]

  tags = {
    Name   = "Eks-cluster"
  }

}

resource "aws_iam_role" "eks_worker_role" {
  name               = "eks-worker-node-role"  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"  
        }
      }
    ]
  })
}
# Step 3: Attach each policy in the list to the IAM role using count
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy_attachment" {
  count      = length(var.worker_node_policies) 
  role       = aws_iam_role.eks_worker_role.name
  policy_arn = var.worker_node_policies[count.index]
}


# Step 10: Create EKS Node Group (Worker Node Group)
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "my-node-group"
  node_role_arn   = aws_iam_role.eks_worker_role.arn 
  subnet_ids      = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  instance_types  = ["t2.medium"] 
  disk_size       = 20  
  ami_type         = "AL2_x86_64"
  capacity_type    = "ON_DEMAND"  
  
  tags = {
    "Name"        = "eks-worker-node-group"
  }

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }
  depends_on = [aws_iam_role_policy_attachment.eks_worker_node_policy_attachment]
}
