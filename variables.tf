####################################################################################################
# Required Variables
variable "project_name" {
  description = "Project name used for naming and the Project tag."
  type        = string
}

variable "instance_name" {
  description = "The name of the instance."
  type        = string
}

variable "ingress_rules" {
  description = "List of ingress rules for the instance security group. Access is via SSM Session Manager by default; only open inbound ports you actually serve (e.g. 80/443)."
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}

####################################################################################################
# Tagging
variable "additional_tags" {
  description = "Additional tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}

variable "instance_tags" {
  description = "Tags to apply only to the EC2 instance resource."
  type        = map(string)
  default     = {}
}

####################################################################################################
# Instance Configuration
variable "instance_type" {
  description = "The instance type to use for the instance."
  type        = string
  default     = "t4g.small"
}

variable "ami_name" {
  description = "The name (or name pattern) of the AMI to use for the instance."
  type        = string
  default     = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-20250610"
}

variable "ami_owner" {
  description = "The owner account ID of the AMI."
  type        = string
  default     = "099720109477"
}

variable "volume_size" {
  description = "The size of the root volume in GB."
  type        = number
  default     = 30
}

variable "user_data_script_path" {
  description = "Path to a user data script to run on first boot."
  type        = string
  default     = ""
}

variable "disable_api_termination" {
  description = "Controls whether API termination is disabled."
  type        = bool
  default     = false
}

variable "disable_api_stop" {
  description = "Controls whether API stop is disabled."
  type        = bool
  default     = false
}

variable "allocate_eip" {
  description = "Controls whether an Elastic IP should be allocated."
  type        = bool
  default     = true
}

variable "egress_rules" {
  description = "List of egress rules for the instance security group. Defaults to unrestricted outbound, which SSM Session Manager and OS package updates require. Narrow this if your environment provides SSM VPC endpoints."
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

####################################################################################################
# Networking
variable "create_vpc" {
  description = "Create a minimal public VPC (single subnet + IGW) for the instance. Set false to place the instance in an existing VPC via vpc_id/subnet_id."
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "ID of an existing VPC to use when create_vpc is false."
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "ID of an existing subnet to use when create_vpc is false."
  type        = string
  default     = ""
}

variable "availability_zone" {
  description = "Availability zone for the created subnet. Leave empty for default placement."
  type        = string
  default     = ""
}

variable "user_data" {
  description = "Rendered user-data content passed directly to the instance. Takes precedence over user_data_script_path when set. Use this for templated user-data (e.g. templatefile()) where the content isn't a static file on disk."
  type        = string
  default     = ""
}

####################################################################################################
# S3 Access
variable "enable_s3_bucket_policy" {
  description = "Attach an S3 access policy (scoped to s3_bucket_name) to the instance role."
  type        = bool
  default     = false
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket the instance role may access."
  type        = string
  default     = ""
}

####################################################################################################
# Public DNS
variable "enable_public_dns" {
  description = "Create a public Route53 A record pointing at the instance's EIP."
  type        = bool
  default     = false
}

variable "apex_domain" {
  description = "Apex domain whose hosted zone holds the DNS record."
  type        = string
  default     = ""
}

variable "dns_name" {
  description = "FQDN for the public DNS record."
  type        = string
  default     = ""
}

variable "enable_route53_policy" {
  description = "Attach a Route53 policy (scoped to route53_zone_id) to the instance role, for DNS-01 ACME challenges such as certbot cert issuance/renewal."
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID the instance may modify for DNS-01 challenges. Required when enable_route53_policy is true."
  type        = string
  default     = ""
}
