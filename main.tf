provider "aws" { 
region = "ap-south-1"   
}
 
 
resource "aws_vpc" "main" {                            
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = var.is_enabled
  enable_dns_hostnames = var.is_enabled   

  tags = {
    Name = "MainVPC"
  }
}

resource "aws_subnet" "public_subnet" {    
  vpc_id                  = aws_vpc.main.id      
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = var.is_enabled
  availability_zone       = var.availability_zones[0]

  tags = {
    Name = "Public_Subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = var.availability_zones[1]

  tags = {
    Name = "private_Subnet"
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

  tags = {
    Name = "PublicRouteTable"
  }
}
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "privateroutetable"
  }
}



resource "aws_route_table_association" "subnet_1_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "subnet_2_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_security_group" "efs-sg" {
  name        = "efs"
  description = "Allow inbound and outbound traffic"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "efs_sg"
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
resource "aws_instance" "example" {
  
  ami                = "ami-03793655b06c6e29a"
  instance_type      = "t3.micro"
  key_name           = "efs"
  subnet_id          = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.efs-sg.id]
  availability_zone  = "ap-south-1a"

  tags = {
    Name = "instance-1"
  }
}
resource "aws_instance" "instance" {
  
  ami                = "ami-03793655b06c6e29a"
  instance_type      = "t3.micro"
  key_name           = "efs"
  subnet_id          = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.efs-sg.id]
  availability_zone  = "ap-south-1b"

  tags = { 
    Name = "instance-2"
  }
}



resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.ap-south-1.s3"

  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_rt.id]

  policy = jsonencode({
    Statement = [
      {
        Action   = "*"
        Effect   = "Allow"
        Resource = "*"
        Principal = "*"
      }
    ]
  })
}


