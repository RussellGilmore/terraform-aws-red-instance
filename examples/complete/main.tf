variable "project_name" {
  type    = string
  default = "red-instance-example"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "instance_name" {
  type    = string
  default = "red-example"
}

provider "aws" {
  region = var.region
}

module "red_instance" {
  source = "../../"

  project_name  = var.project_name
  instance_name = var.instance_name

  # Access is via SSM Session Manager — no SSH. Only HTTP/HTTPS are opened.
  ingress_rules = [
    {
      description = "HTTP from anywhere"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTPS from anywhere"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
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
  description = "The primary private IPv4 address of the red instance."
  value       = module.red_instance.private_ip
}
