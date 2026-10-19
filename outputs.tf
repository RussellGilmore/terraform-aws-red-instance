output "instance_id" {
  description = "The ID of the EC2 instance."
  value       = aws_instance.red-instance.id
}

output "vpc_id" {
  description = "The VPC ID the instance is deployed in — created by the module when create_vpc is true, or the supplied vpc_id when false."
  value       = var.create_vpc ? aws_vpc.main[0].id : var.vpc_id
}

output "subnet_id" {
  description = "The subnet ID the instance is deployed in — created by the module when create_vpc is true, or the supplied subnet_id when false."
  value       = var.create_vpc ? aws_subnet.public[0].id : var.subnet_id
}

output "public_ip" {
  description = "The public IP address of the instance (EIP when allocated)."
  value       = var.allocate_eip ? aws_eip.red_instance_eip[0].public_ip : "Public IP not allocated"
}

output "private_ip" {
  description = "The primary private IPv4 address of the instance — the pinned private_ip when set, otherwise the one AWS assigned."
  value       = aws_instance.red-instance.private_ip
}

output "public_dns" {
  description = "The public DNS name of the instance."
  value       = var.enable_public_dns ? aws_route53_record.red_instance_dns[0].fqdn : "Public DNS not allocated"
}

output "security_group_id" {
  description = "The ID of the instance security group."
  value       = aws_security_group.red_sg.id
}
