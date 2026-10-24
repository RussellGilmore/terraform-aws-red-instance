variable "project_name" {
  type    = string
  default = "red-instance-existing-net"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "instance_name" {
  type    = string
  default = "red-existing"
}

provider "aws" {
  region = var.region
}

# Justification: Flow Logs and other features are not required for a red instance.
# trivy:ignore:AVD-AWS-0178
resource "aws_vpc" "this" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.project_name}-igw" }
}

# Justification: This is a public subnet for the red instance
# trivy:ignore:AVD-AWS-0164
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.20.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"
  tags                    = { Name = "${var.project_name}-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Stands in for a load balancer's security group: the instance admits
# traffic from members of this group rather than from a CIDR.
resource "aws_security_group" "source" {
  name        = "${var.project_name}-source-sg"
  description = "Example source security group (stands in for a load balancer)"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.project_name}-source-sg" }
}

module "red_instance" {
  source = "../../"

  project_name  = var.project_name
  instance_name = var.instance_name

  create_vpc = false
  vpc_id     = aws_vpc.this.id
  subnet_id  = aws_subnet.public.id
  private_ip = "10.20.1.10"

  ingress_rules = [
    {
      description = "HTTPS from anywhere"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description     = "App port from the source security group only"
      from_port       = 8080
      to_port         = 8080
      protocol        = "tcp"
      security_groups = [aws_security_group.source.id]
    },
  ]

  additional_tags = {
    Environment = "example"
  }
}

output "instance_id" {
  description = "The ID of the red instance."
  value       = module.red_instance.instance_id
}

output "public_ip" {
  description = "The public IP address of the red instance."
  value       = module.red_instance.public_ip
}

output "private_ip" {
  description = "Private IP reported by the module — should equal the pinned address."
  value       = module.red_instance.private_ip
}

output "vpc_id" {
  description = "VPC ID — should equal the externally-created VPC, not a module-created one."
  value       = module.red_instance.vpc_id
}

output "supplied_vpc_id" {
  description = "The externally-created VPC ID, for cross-checking against the module output."
  value       = aws_vpc.this.id
}

output "security_group_id" {
  description = "The instance's security group, whose rules the test inspects."
  value       = module.red_instance.security_group_id
}

output "source_security_group_id" {
  description = "The source security group the 8080 rule should reference."
  value       = aws_security_group.source.id
}
