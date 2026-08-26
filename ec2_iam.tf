# This file creates the IAM role and instance profile for the Red Instance.

# The role has a trust policy that allows EC2 instances to assume the role.
resource "aws_iam_instance_profile" "red_instance_profile" {
  name = "${lower(var.instance_name)}-red-instance-profile"
  role = aws_iam_role.red_role.name

  tags = local.tags
}

# Create the IAM role for the Red Instance
resource "aws_iam_role" "red_role" {
  name = "${lower(var.instance_name)}-role"

  tags = local.tags

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# AmazonSSMManagedInstanceCore enables Session Manager access. This is the
# primary access path for the instance — no SSH key pair is used.
resource "aws_iam_role_policy_attachment" "red_ssm_policy_attachment" {
  role       = aws_iam_role.red_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Role policy for S3 bucket access
resource "aws_iam_role_policy" "s3_bucket_policy" {
  name = "${lower(var.instance_name)}-s3-bucket-policy"
  role = aws_iam_role.red_role.name

  count = var.enable_s3_bucket_policy ? 1 : 0

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${var.s3_bucket_name}",
        "arn:aws:s3:::${var.s3_bucket_name}/*"
      ]
    }
  ]
}
EOF
}

# Role policy for Route53 DNS-01 ACME challenges (e.g. certbot cert issuance
# and renewal). Scoped to a single hosted zone plus the account-level calls
# the certbot route53 plugin requires.
resource "aws_iam_role_policy" "route53_policy" {
  name = "${lower(var.instance_name)}-route53-policy"
  role = aws_iam_role.red_role.name

  count = var.enable_route53_policy ? 1 : 0

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "route53:GetChange",
      "Resource": "arn:aws:route53:::change/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/${var.route53_zone_id}"
    },
    {
      "Effect": "Allow",
      "Action": "route53:ListHostedZones",
      "Resource": "*"
    }
  ]
}
EOF
}
