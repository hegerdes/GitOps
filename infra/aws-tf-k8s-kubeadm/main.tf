################################################################################
# Data & Locals
################################################################################
data "aws_availability_zones" "available" {}

locals {
  name   = "k8s-kubeadm"
  region = "eu-central-1"

  tags = {
    project   = local.name
    owner     = "hegerdes"
    managedby = "terraform"
  }
  controlplane_tags = merge(local.tags,
    {
      k8s = "true"
      app = "k8s"
  })

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  ssh_keys        = [file("~/.ssh/id_rsa.pub")]
  cloud_init_path = "${path.module}/cloud-init.yml"
}

################################################################################
# VPC Module
################################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~>5.19"

  name                                                          = local.name
  azs                                                           = local.azs
  cidr                                                          = local.vpc_cidr
  enable_ipv6                                                   = true
  private_subnet_enable_resource_name_dns_aaaa_record_on_launch = true

  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 4)]

  public_subnet_ipv6_prefixes                    = [0, 1, 2]
  public_subnet_assign_ipv6_address_on_creation  = true
  private_subnet_assign_ipv6_address_on_creation = true
  private_subnet_ipv6_prefixes                   = [3, 4, 5]

  # # This is for ipv6 only - which does not work with LBs, RDS, etc.
  # public_subnet_ipv6_native    = true
  # private_subnet_ipv6_native   = true

  # RDS currently only supports dual-stack so IPv4 CIDRs will need to be provided for subnets
  # database_subnet_ipv6_native   = true
  # database_subnet_ipv6_prefixes = [6, 7, 8]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  create_egress_only_igw = true

  tags = local.tags
}

################################################################################
# IAM Role Compute
################################################################################
resource "aws_iam_role" "ec2" {
  name = "${local.name}-compute"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2.name
  tags = local.tags
}
################################################################################
# CP Autoscale Group
################################################################################
resource "aws_placement_group" "cp" {
  name     = "${local.name}-cp"
  strategy = "spread"
  tags     = local.tags
}

resource "aws_lb_target_group" "cp" {
  name        = "${local.name}-cp"
  protocol    = "TCP"
  port        = 6443
  target_type = "instance"
  vpc_id      = module.vpc.vpc_id
  tags        = local.tags
  # connection_termination = true
  # preserve_client_ip     = true

  health_check {
    protocol            = "TCP"
    port                = 6443
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
  }

  target_health_state {
    enable_unhealthy_connection_termination = false
  }
}

resource "aws_autoscaling_group" "cp" {
  name                      = "${local.name}-cp"
  max_size                  = 2
  min_size                  = 1
  health_check_grace_period = 300
  desired_capacity          = 1
  force_delete              = true
  placement_group           = aws_placement_group.cp.id
  vpc_zone_identifier       = module.vpc.private_subnets
  target_group_arns         = [aws_lb_target_group.cp.arn]

  launch_template {
    id      = aws_launch_template.cp.id
    version = aws_launch_template.cp.latest_version
  }

  timeouts {
    delete = "10m"
  }

  dynamic "tag" {
    for_each = local.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
# resource "aws_autoscaling_group" "worker" {
#   name                      = "${local.name}-worker"
#   max_size                  = 2
#   min_size                  = 1
#   health_check_grace_period = 300
#   desired_capacity          = 1
#   force_delete              = true
#   placement_group           = aws_placement_group.cp.id
#   vpc_zone_identifier       = module.vpc.private_subnets
#   target_group_arns         = [aws_lb_target_group.cp.arn]

#   launch_template {
#     id      = aws_launch_template.cp.id
#     version = aws_launch_template.cp.latest_version
#   }

#   timeouts {
#     delete = "10m"
#   }

#   dynamic "tag" {
#     for_each = local.tags
#     content {
#       key                 = tag.key
#       value               = tag.value
#       propagate_at_launch = true
#     }
#   }
# }

resource "aws_launch_template" "cp" {
  name_prefix   = local.name
  image_id      = data.aws_ami.boot_amd64.id
  instance_type = "t3a.small"
  ebs_optimized = true
  tags          = local.tags

  user_data = base64encode(templatefile(local.cloud_init_path, {
    ssh_keys = local.ssh_keys,
  }))

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2.arn
  }

  block_device_mappings {
    device_name  = "/dev/xvdf" # Adjust if your AMI expects a different root device name
    virtual_name = "ephemeraldata0"
    ebs {
      volume_size           = 40
      volume_type           = "gp3"
      encrypted             = true
      throughput            = 200
      delete_on_termination = true
    }
  }

  instance_market_options {
    market_type = "spot"
  }

  network_interfaces {
    subnet_id             = element(module.vpc.private_subnets, 0)
    security_groups       = [module.security_group.security_group_id]
    ipv6_address_count    = 1
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "optional"
    http_protocol_ipv6          = "enabled"
    instance_metadata_tags      = "enabled"
  }

  tag_specifications {
    resource_type = "instance"
    tags          = local.controlplane_tags
  }
  tag_specifications {
    resource_type = "volume"
    tags          = local.controlplane_tags
  }
}
################################################################################
# Controlplane Loadbalancer
################################################################################
module "cp_lb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~>9.14"

  name = local.name
  tags = local.tags

  vpc_id                     = module.vpc.vpc_id
  subnets                    = module.vpc.public_subnets
  load_balancer_type         = "network"
  security_groups            = [module.security_group.security_group_id]
  ip_address_type            = "dualstack"
  enable_deletion_protection = false

  listeners = {
    kubeapi = {
      port     = 6443
      protocol = "TCP"
      forward = {
        arn = aws_lb_target_group.cp.arn
      }
    }
  }
}

################################################################################
# Supporting Resources
################################################################################
data "aws_ami" "boot_amd64" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["debian-12-amd64*"]
  }
}

resource "aws_key_pair" "default" {
  for_each   = toset(local.ssh_keys)
  key_name   = sha256(each.key)
  public_key = each.key
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.3"

  name        = local.name
  description = "Security group for example usage with EC2 instance"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks      = ["0.0.0.0/0"]
  ingress_ipv6_cidr_blocks = ["::/0"]
  ingress_rules            = ["http-80-tcp", "https-443-tcp", "kubernetes-api-tcp", "all-icmp", "ssh-tcp"]
  egress_rules             = ["all-all"]

  tags = local.tags
}

# ssh root@i-001167e6b1c91fec1 -o ProxyCommand='aws ec2-instance-connect open-tunnel --instance-id %h --region eu-central-1'
resource "aws_ec2_instance_connect_endpoint" "default" {
  subnet_id          = module.vpc.private_subnets[0]
  security_group_ids = [module.security_group.security_group_id]
}

resource "aws_kms_key" "this" {}
