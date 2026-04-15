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

resource "aws_subnet" "public_subnet1" {    
  vpc_id                  = aws_vpc.main.id      
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = var.is_enabled
  availability_zone       = var.availability_zones[0]

  tags = {
    Name = "Public_Subnet1"
  }
}

resource "aws_subnet" "public_subnet2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = var.availability_zones[1]

  tags = {
    Name = "public_Subnet2"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "MainIGW"
  }
}

resource "aws_route_table" "public_rt1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable1"
  }
}
resource "aws_route_table" "public_rt2" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "publicroutetable2"
  }
}



resource "aws_route_table_association" "subnet_1_assoc" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public_rt1.id
}

resource "aws_route_table_association" "subnet_2_assoc" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.public_rt2.id
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
  subnet_id          = aws_subnet.public_subnet1.id
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
  subnet_id          = aws_subnet.public_subnet2.id
  vpc_security_group_ids = [aws_security_group.efs-sg.id]
  availability_zone  = "ap-south-1b"

  tags = { 
    Name = "instance-2"
  }
}

resource "aws_lb" "nlb" {
  name               = "my-nlb"
  internal           = false
  load_balancer_type = "network" 

  subnets = [
    aws_subnet.public_subnet1.id,
    aws_subnet.public_subnet2.id
  ]

  enable_cross_zone_load_balancing = true
}
resource "aws_lb_target_group" "tg" {
  name     = "nlb-target-group"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id

  health_check {
    protocol = "TCP"
    port     = "traffic-port"
  }
}


resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# Attach instances
resource "aws_lb_target_group_attachment" "t1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.example.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "t2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.instance.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.example.id
  port             = 80
}

provider "aws" {
  region = "ap-south-1"
}

# -------------------------
# VPC
# -------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# -------------------------
# Subnets (2 AZs)
# -------------------------
resource "aws_subnet" "subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
}

# -------------------------
# Internet Gateway
# -------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# -------------------------
# Route Table
# -------------------------
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.rt.id
}

# -------------------------
# Security Group (for EC2)
# -------------------------
resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------
# Launch Template
# -------------------------
resource "aws_launch_template" "lt" {
  name_prefix   = "nlb-template"
  image_id      = "ami-0f5ee92e2d63afc18" # Amazon Linux (update if needed)
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y nginx
              systemctl start nginx
              systemctl enable nginx
              echo "Hello from NLB Auto Scaling" > /usr/share/nginx/html/index.html
              EOF
  )
}

# -------------------------
# Target Group
# -------------------------
resource "aws_lb_target_group" "tg" {
  name     = "nlb-target-group"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id

  health_check {
    protocol = "TCP"
    port     = "traffic-port"
  }
}

# -------------------------
# Network Load Balancer
# -------------------------
resource "aws_lb" "nlb" {
  name               = "my-nlb"
  load_balancer_type = "network"
  subnets            = [
    aws_subnet.subnet_1.id,
    aws_subnet.subnet_2.id
  ]
}

# -------------------------
# Listener
# -------------------------
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# -------------------------
# Auto Scaling Group
# -------------------------
resource "aws_autoscaling_group" "asg" {
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1
  vpc_zone_identifier = [
    aws_subnet.subnet_1.id,
    aws_subnet.subnet_2.id
  ]

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.tg.arn]
}


provider "aws" {
  region = "ap-south-1"
}

# -------------------------
# VPC
# -------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# -------------------------
# Subnets (2 AZs)
# -------------------------
resource "aws_subnet" "subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
}

# -------------------------
# Internet Gateway
# -------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# -------------------------
# Route Table
# -------------------------
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.rt.id
}

# -------------------------
# Security Group (for EC2)
# -------------------------
resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------
# Launch Template
# -------------------------
resource "aws_launch_template" "lt" {
  name_prefix   = "nlb-template"
  image_id      = "ami-0f5ee92e2d63afc18" # Amazon Linux (update if needed)
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y nginx
              systemctl start nginx
              systemctl enable nginx
              echo "Hello from NLB Auto Scaling" > /usr/share/nginx/html/index.html
              EOF
  )
}

# -------------------------
# Target Group
# -------------------------
resource "aws_lb_target_group" "tg" {
  name     = "nlb-target-group"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id

  health_check {
    protocol = "TCP"
    port     = "traffic-port"
  }
}

# -------------------------
# Network Load Balancer
# -------------------------
resource "aws_lb" "nlb" {
  name               = "my-nlb"
  load_balancer_type = "network"
  subnets            = [
    aws_subnet.subnet_1.id,
    aws_subnet.subnet_2.id
  ]
}

# -------------------------
# Listener
# -------------------------
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# -------------------------
# Auto Scaling Group
# -------------------------
resource "aws_autoscaling_group" "asg" {
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1
  vpc_zone_identifier = [
    aws_subnet.subnet_1.id,
    aws_subnet.subnet_2.id
  ]

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.tg.arn]
}

# -------------------------
# Scaling Policy
# -------------------------
resource "aws_autoscaling_policy" "cpu_policy" {
  name                   = "cpu-scaling-policy"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.asg.name

  target_tracking_configuration {
    target_value = 50.0

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}
# -------------------------
# Scaling Policy
# -------------------------
resource "aws_autoscaling_policy" "cpu_policy" 
  name                   = "cpu-scaling-policy"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.asg.name

  target_tracking_configuration {
    target_value = 50.0

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}

launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.tg.arn]
}
