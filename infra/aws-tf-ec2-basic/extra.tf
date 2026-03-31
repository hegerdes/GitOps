resource "aws_key_pair" "default" {
  key_name   = local.name
  public_key = tls_private_key.default.public_key_openssh
}

resource "tls_private_key" "default" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "ssh_key" {
  content  = tls_private_key.default.private_key_openssh
  filename = "${path.module}/data/web-key"
}

resource "aws_iam_role" "ec2" {
  name = "${local.name}-ec2"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Effect = "Allow",
        Principal = {
          Service = "dlm.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }

    ]
  })
  tags = local.tags
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name}-profile"
  role = aws_iam_role.ec2.name
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_vpc" "selected" {
  id = local.vpc_id
}

data "aws_subnet" "default" {
  id = local.subnet_id
}

data "aws_ami" "boot_ami_x86" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["debian-13-amd64*"]
  }
}
data "aws_ami" "boot_ami_arm" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["debian-13-arm64*"]
  }
}
