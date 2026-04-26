locals {
  name = "cri-bench"

  # I need nested virtualization
  # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/amazon-ec2-nested-virtualization.html
  instance_type   = "c8i.large"
  cloud_init_path = "${path.module}/data/cloud-init.yaml"
  subnet_id       = "subnet-00a0c5d6ae9b14595"
  vpc_id          = "vpc-087d67aa94f1c1291"

  tags = {
    owner     = "Henrik Gerdes"
    managedby = "terraform"
    project   = local.name
  }
}

resource "aws_instance" "web" {
  tags          = merge(local.tags, { "Name" : local.name })
  ebs_optimized = true
  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }
  root_block_device {
    throughput  = 500
    iops        = 15000
    volume_type = "gp3"
    volume_size = 80
  }
  instance_market_options {
    market_type = "spot"
  }
}


resource "aws_launch_template" "web" {
  name_prefix   = local.name
  image_id      = data.aws_ami.boot_ami_x86.id
  instance_type = local.instance_type
  ebs_optimized = true
  tags          = local.tags


  user_data = base64encode(templatefile(local.cloud_init_path, {
    extra_disks = false
    ssh_keys    = [tls_private_key.default.public_key_openssh]
  }))

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2.arn
  }

  cpu_options {
    nested_virtualization = "enabled"
  }

  # block_device_mappings {
  #   device_name  = "/dev/xvdf" # Adjust if your AMI expects a different root device name
  #   virtual_name = "ephemeraldata0"
  #   ebs {
  #     volume_size           = 80
  #     volume_type           = "gp3"
  #     encrypted             = true
  #     throughput            = 600
  #     iops                  = 30000
  #     delete_on_termination = true
  #   }
  # }

  network_interfaces {
    subnet_id                   = data.aws_subnet.default.id
    security_groups             = [module.security_group.security_group_id]
    delete_on_termination       = true
    associate_public_ip_address = true
    ipv6_address_count          = 1
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "optional"
    instance_metadata_tags      = "enabled"
  }

  private_dns_name_options {
    hostname_type = "resource-name"
  }

  tag_specifications {
    resource_type = "instance"
    tags          = local.tags
  }
  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.tags, {})
  }
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.3"

  name        = local.name
  description = "Security group for EC2 instance ${local.name}"
  vpc_id      = data.aws_vpc.selected.id

  ingress_ipv6_cidr_blocks = ["::/0"]
  ingress_cidr_blocks      = ["0.0.0.0/0"]
  ingress_rules            = ["http-80-tcp", "https-443-tcp", "ssh-tcp"]
  egress_rules             = ["all-all"]

  tags = local.tags
}


resource "aws_network_interface" "monitoring" {
  subnet_id       = data.aws_subnet.default.id
  security_groups = [module.security_group.security_group_id]

  tags = {
    Name = "primary_network_interface"
  }
}

# resource "aws_instance" "monitoring" {
#   tags          = merge(local.tags, { "Name" : "${local.name}-monitoring" })
#   ebs_optimized = true
#   ami           = data.aws_ami.boot_ami_arm
#   instance_type = "t4g.small"
#   key_name      = aws_key_pair.default.key_name

#   primary_network_interface {
#     network_interface_id = aws_network_interface.monitoring.id
#   }

#   user_data = templatefile(local.cloud_init_path, {
#     extra_disks = true
#     ssh_keys    = [tls_private_key.default.public_key_openssh]
#   })
# }

output "instance_ip" {
  value = aws_instance.web.public_ip
}
output "instance_dns" {
  value = aws_instance.web.public_dns
}
output "instance_id" {
  value = aws_instance.web.id
}
output "amis" {
  value = {
    amd = data.aws_ami.boot_ami_x86.id
    arm = data.aws_ami.boot_ami_arm.id
  }
}
