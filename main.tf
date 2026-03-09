#####################################
# Provider Configuration
#####################################

provider "aws" {
  region = var.region
}

#####################################
# Variables
#####################################

variable "region" {
  default = "ap-northeast-2"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "instance_type" {
  default = "t3.micro"
}

#####################################
# VPC
#####################################

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "test-terraform-vpc"
  }
}

#####################################
# Internet Gateway
#####################################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-igw"
  }
}

#####################################
# Availability Zones
#####################################

data "aws_availability_zones" "available" {}

#####################################
# Public Subnets (2 AZs)
#####################################

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index}"
  }
}

#####################################
# Route Table + Route + Association
#####################################

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

#####################################
# Security Group
#####################################

resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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

#####################################
# AMI Data Source
#####################################

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

#####################################
# EC2 Instances
#####################################

resource "aws_instance" "web" {
  count         = 2
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public[count.index].id
  security_groups = [aws_security_group.web_sg.id]

  user_data = file("userdata.sh")

  tags = {
    Name = "web-${count.index}"
  }
}

#####################################
# Application Load Balancer
#####################################

resource "aws_lb" "app_lb" {
  name               = "terraform-alb"
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.web_sg.id]
}

#####################################
# Target Group
#####################################

resource "aws_lb_target_group" "tg" {
  name     = "terraform-tg-123"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

#####################################
# Target Group Attachments
#####################################

resource "aws_lb_target_group_attachment" "attach" {
  count            = 2
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}

#####################################
# Listener
#####################################

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

#####################################
# Random ID for S3
#####################################

resource "random_id" "rand" {
  byte_length = 4
}

#####################################
# S3 Bucket
#####################################

resource "aws_s3_bucket" "bucket" {
  bucket = "terraform-html-demo-${random_id.rand.hex}"
}
