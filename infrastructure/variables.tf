variable "aws_region" {
  description = "AWS region for infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "game-automation"
}

variable "allowed_ssh_ips" {
  description = "List of IPs allowed to SSH to build servers"
  type        = list(string)
  default     = ["0.0.0.0/0"] # CHANGE THIS to your IP!
}

variable "allowed_rdp_ips" {
  description = "List of IPs allowed to RDP to Windows build servers"
  type        = list(string)
  default     = ["0.0.0.0/0"] # CHANGE THIS to your IP!
}

variable "enable_unity_builder" {
  description = "Enable Unity build server"
  type        = bool
  default     = true
}

variable "enable_ue5_builder" {
  description = "Enable UE5 build server"
  type        = bool
  default     = true
}

variable "unity_instance_type" {
  description = "EC2 instance type for Unity builds"
  type        = string
  default     = "c5.4xlarge" # 16 vCPU, 32GB RAM
}

variable "ue5_instance_type" {
  description = "EC2 instance type for UE5 builds"
  type        = string
  default     = "c5.9xlarge" # 36 vCPU, 72GB RAM (UE5 needs POWER)
}

variable "build_retention_days" {
  description = "Number of days to retain builds in S3"
  type        = number
  default     = 30
}
