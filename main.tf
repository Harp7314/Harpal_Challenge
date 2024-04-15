provider "aws" {
  region = "us-east-2" 
}

# VPC
resource "aws_vpc" "lab_vpc" {
  cidr_block       = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "VPC-Lab"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "lab_igw" {
  vpc_id = aws_vpc.lab_vpc.id

  tags = {
    Name = "VPC-Lab-IGW"
  }
}

# Public Subnets
resource "aws_subnet" "public_subnets" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = element(var.availability_zones, count.index)

  tags = {
    Name = "public_subnet-${count.index}"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnets" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.lab_vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name = "private_subnet-${count.index}"
  }
}

# NAT Gateway (for one AZ)
resource "aws_eip" "nat_eip" {
  count = 1

  domain = "vpc"

  tags = {
    Name = "NAT-EIP-${count.index}"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  count         = 1
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public_subnets[0].id

  tags = {
    Name = "NAT-Gateway-${count.index}"
  }
}

# Route Tables
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.lab_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab_igw.id
  }

  tags = {
    Name = "public_route_table"
  }
}

resource "aws_route_table_association" "public_route_association" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

# Create key-pair for EC2 
resource "aws_key_pair" "TF_key" {
  key_name   = "TF_key"
  public_key = tls_private_key.rsa.public_key_openssh
}

# Create private key
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create local file for private key to be stored
resource "local_file" "TF_Key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "tfkey"
}



# Security Group
resource "aws_security_group" "allow_http_https" {
  name        = "allow_http_https"
  description = "Allow HTTP and HTTPS inbound traffic"
  vpc_id      = aws_vpc.lab_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
   
  }


  ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]

    }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

  tags = {
    Name = "allow_http_https"
  }
}


# Create Target Group. It acts as a logical group of EC2 instances that receive traffic from the Application Load Balancer.
resource "aws_lb_target_group" "my_target_group" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.lab_vpc.id
}

# Application Load Balancer (ALB) 
resource "aws_lb" "my_alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_http_https.id]
  subnets            = aws_subnet.public_subnets[*].id

  tags = {
    Name = "MyALB"
  }
}

# ALB Listener for HTTP
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}


### ALB Listener for HTTPS
##resource "aws_lb_listener" "https_listener" {
##  load_balancer_arn = aws_lb.my_alb.arn
##  port              = 443
##  protocol          = "HTTPS"
##  ssl_policy        = "ELBSecurityPolicy-2016-08"
##  ## certificate_arn   = "arn:aws:acm:region:account-id:certificate/certificate-id"
##
##  default_action {
##    type             = "forward"
##    target_group_arn = aws_lb_target_group.my_target_group.arn
##  }
##}


# EC2 Instance
resource "aws_instance" "public_instances" {
  count = length(var.public_subnet_cidrs)

  depends_on = [aws_security_group.allow_http_https]
  ami             = "ami-0c55b159cbfafe1f0" # Replace with your AMI ID
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public_subnets[count.index].id
  associate_public_ip_address = true
  key_name        = aws_key_pair.TF_key.key_name  # Replace with your key pair name
  security_groups = [aws_security_group.allow_http_https.id]

  tags = {
    Name = "Public-Instance-${count.index}"
  }
}

