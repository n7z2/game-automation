terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC for build infrastructure
resource "aws_vpc" "game_build_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "game-build-vpc"
    Environment = var.environment
  }
}

# Public subnet for build servers
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.game_build_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "game-build-public-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.game_build_vpc.id

  tags = {
    Name = "game-build-igw"
  }
}

# Route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.game_build_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "game-build-public-rt"
  }
}

resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Security group for build servers
resource "aws_security_group" "build_server_sg" {
  name        = "game-build-server-sg"
  description = "Security group for game build servers"
  vpc_id      = aws_vpc.game_build_vpc.id

  # SSH access (restrict to your IP)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_ips
    description = "SSH access"
  }

  # RDP access for Windows (restrict to your IP)
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = var.allowed_rdp_ips
    description = "RDP access"
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "game-build-server-sg"
  }
}

# S3 bucket for build artifacts
resource "aws_s3_bucket" "build_artifacts" {
  bucket = "${var.project_name}-game-builds-${var.environment}"

  tags = {
    Name        = "Game Build Artifacts"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "build_artifacts_versioning" {
  bucket = aws_s3_bucket.build_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "build_artifacts_lifecycle" {
  bucket = aws_s3_bucket.build_artifacts.id

  rule {
    id     = "delete-old-builds"
    status = "Enabled"

    expiration {
      days = var.build_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# IAM role for build servers
resource "aws_iam_role" "build_server_role" {
  name = "game-build-server-role"

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

resource "aws_iam_role_policy" "build_server_s3_policy" {
  name = "build-server-s3-policy"
  role = aws_iam_role.build_server_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.build_artifacts.arn,
          "${aws_s3_bucket.build_artifacts.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "build_server_profile" {
  name = "game-build-server-profile"
  role = aws_iam_role.build_server_role.name
}

# Unity build server (Ubuntu)
resource "aws_instance" "unity_build_server" {
  count = var.enable_unity_builder ? 1 : 0

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.unity_instance_type
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.build_server_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.build_server_profile.name

  root_block_device {
    volume_size = 200
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user-data/unity-setup.sh", {
    s3_bucket = aws_s3_bucket.build_artifacts.bucket
  })

  tags = {
    Name        = "unity-build-server"
    Environment = var.environment
    Purpose     = "Unity Build Automation"
  }
}

# UE5 build server (Windows)
resource "aws_instance" "ue5_build_server" {
  count = var.enable_ue5_builder ? 1 : 0

  ami                    = data.aws_ami.windows.id
  instance_type          = var.ue5_instance_type
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.build_server_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.build_server_profile.name

  root_block_device {
    volume_size = 500
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user-data/ue5-setup.ps1", {
    s3_bucket = aws_s3_bucket.build_artifacts.bucket
  })

  tags = {
    Name        = "ue5-build-server"
    Environment = var.environment
    Purpose     = "UE5 Build Automation"
  }
}

# AMI data sources
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "windows" {
  most_recent = true
  owners      = ["801119661308"] # Amazon

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# CloudWatch log group for build logs
resource "aws_cloudwatch_log_group" "build_logs" {
  name              = "/aws/game-builds/${var.environment}"
  retention_in_days = 30

  tags = {
    Environment = var.environment
  }
}

# Outputs
output "unity_build_server_ip" {
  value       = var.enable_unity_builder ? aws_instance.unity_build_server[0].public_ip : null
  description = "Public IP of Unity build server"
}

output "ue5_build_server_ip" {
  value       = var.enable_ue5_builder ? aws_instance.ue5_build_server[0].public_ip : null
  description = "Public IP of UE5 build server"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.build_artifacts.bucket
  description = "S3 bucket for build artifacts"
}

output "build_artifacts_url" {
  value       = "s3://${aws_s3_bucket.build_artifacts.bucket}"
  description = "S3 URL for build artifacts"
}
