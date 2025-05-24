
# ################################################################################
# # EC2 Module
# ################################################################################
# module "controlplane" {
#   source  = "terraform-aws-modules/ec2-instance/aws"
#   version = "~>5.7"

#   name          = local.name
#   tags          = local.controlplane_tags
#   instance_tags = local.controlplane_tags
#   volume_tags   = local.controlplane_tags
#   eip_tags      = local.controlplane_tags

#   ami                    = data.aws_ami.boot_amd64.id
#   instance_type          = "t3a.small" #t4g.small
#   availability_zone      = element(module.vpc.azs, 0)
#   subnet_id              = element(module.vpc.private_subnets, 0)
#   vpc_security_group_ids = [module.security_group.security_group_id]
#   key_name               = aws_key_pair.default.key_name


#   create_eip       = false
#   disable_api_stop = false

#   ipv6_address_count   = 1
#   create_spot_instance = true

#   user_data_replace_on_change = false
#   user_data = templatefile(local.cloud_init_path, {
#     ssh_keys = local.ssh_keys,
#   })

#   create_iam_instance_profile = true
#   iam_role_description        = "IAM role for ${local.name} ec2 controlplane"
#   iam_role_policies = {
#     AdministratorAccess = "arn:aws:iam::aws:policy/AdministratorAccess"
#   }

#   root_block_device = [
#     {
#       encrypted   = true
#       volume_type = "gp3"
#       throughput  = 200
#       volume_size = 40
#     },
#   ]

#   #   ebs_block_device = [
#   #     {
#   #       device_name = "/dev/sdf"
#   #       volume_type = "gp3"
#   #       volume_size = 5
#   #       throughput  = 200
#   #       encrypted   = true
#   #       kms_key_id  = aws_kms_key.this.arn
#   #       tags = {
#   #         MountPoint = "/mnt/data"
#   #       }
#   #     }
#   #   ]

# }
