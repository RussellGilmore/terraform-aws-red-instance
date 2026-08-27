# Data source to get the Red Instance AMI
data "aws_ami" "red_ami" {
  most_recent        = true
  include_deprecated = true

  filter {
    name   = "name"
    values = [var.ami_name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [var.ami_owner]
}

# Egress is caller-configurable via var.egress_rules. The default is
# unrestricted outbound because SSM Session Manager (and OS package
# updates) require outbound HTTPS, and the SSM service endpoints are not
# a fixed CIDR range. Consumers with SSM VPC endpoints can narrow this.
# trivy:ignore:AVD-AWS-0104
resource "aws_security_group" "red_sg" {
  vpc_id      = var.create_vpc ? aws_vpc.main[0].id : var.vpc_id
  name        = "${lower(var.instance_name)}-ingress-sg"
  description = "Ingress rules for ${var.instance_name}; access is via SSM Session Manager"

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = var.egress_rules
    content {
      description = egress.value.description
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  tags = merge(
    local.tags,
    { Name = "${lower(var.instance_name)}-ingress-sg" },
    var.instance_tags,
  )
}

# The Red Instance main resource block.
# Access is via SSM Session Manager (see the instance profile in ec2_iam.tf);
# no SSH key pair is created or attached.
resource "aws_instance" "red-instance" {
  ami                     = data.aws_ami.red_ami.id
  instance_type           = var.instance_type
  subnet_id               = var.create_vpc ? aws_subnet.public[0].id : var.subnet_id
  vpc_security_group_ids  = [aws_security_group.red_sg.id]
  disable_api_termination = var.disable_api_termination
  disable_api_stop        = var.disable_api_stop
  # user_data (string) wins over user_data_script_path (file) when both are set.
  user_data            = var.user_data != "" ? var.user_data : (var.user_data_script_path != "" ? file(var.user_data_script_path) : null)
  iam_instance_profile = aws_iam_instance_profile.red_instance_profile.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.volume_size
    delete_on_termination = true
    iops                  = 3000
    throughput            = 125
    encrypted             = true
  }

  tags = merge(
    local.tags,
    { Name = var.instance_name },
    var.instance_tags,
  )
}
