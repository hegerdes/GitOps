# Attach the custom policy to the role
resource "aws_iam_role_policy_attachment" "s3_transit" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.s3-transit.arn
}

resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = "k8s-kubeadm-compute"
}

resource "aws_iam_role_policy_attachment" "vpc_ec2_ipv4" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.vpc_ec2_ipv6.arn
  #   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "vpc_ec2_ipv6" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.vpc_ec2_ipv6.arn
}
resource "aws_iam_role_policy_attachment" "k8s-cloud-controller" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.k8s-cloud-controller.arn
}

resource "aws_iam_policy" "s3-transit" {
  name        = "s3-transit"
  description = "Store cluster data on s3"
  policy      = data.aws_iam_policy_document.s3-transit.json
  tags        = local.tags
}
resource "aws_iam_policy" "vpc_ec2_ipv6" {
  name        = "vpc-ec2-ipv6"
  description = "Allow to manage EC2 network interfaces and private IPs"
  policy      = data.aws_iam_policy_document.vpc_ec2_ipv6.json
  tags        = local.tags
}
resource "aws_iam_policy" "vpc_ec2_ipv4" {
  name        = "vpc-ec2-ipv4"
  description = "Allow to manage EC2 network interfaces and private IPs"
  policy      = data.aws_iam_policy_document.vpc_ec2_ipv4.json
  tags        = local.tags
}
resource "aws_iam_policy" "k8s-cloud-controller" {
  name        = "k8s-cloud-controller"
  description = "Manage AWS resources for Kubernetes"
  policy      = data.aws_iam_policy_document.k8s-cloud-controller.json
  tags        = local.tags
}

data "aws_iam_policy_document" "vpc_ec2_ipv6" {
  statement {
    actions = [
      "ec2:AssignIpv6Addresses",
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeInstanceTypes"
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "ec2:CreateTags"
    ]
    resources = ["arn:aws:ec2:*:*:network-interface/*"]
  }
}
data "aws_iam_policy_document" "vpc_ec2_ipv4" {
  statement {
    actions = [
      "ec2:AssignPrivateIpAddresses",
      "ec2:AttachNetworkInterface",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeSubnets",
      "ec2:DetachNetworkInterface",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:UnassignPrivateIpAddresses"
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "ec2:CreateTags"
    ]
    resources = ["arn:aws:ec2:*:*:network-interface/*"]
  }
}

data "aws_iam_policy_document" "k8s-cloud-controller" {
  statement {
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVolumes",
      "ec2:DescribeAvailabilityZones",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifyVolume",
      "ec2:AttachVolume",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteVolume",
      "ec2:DetachVolume",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DescribeVpcs",
      "ec2:DescribeInstanceTopology",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:AttachLoadBalancerToSubnets",
      "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateLoadBalancerPolicy",
      "elasticloadbalancing:CreateLoadBalancerListeners",
      "elasticloadbalancing:ConfigureHealthCheck",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteLoadBalancerListeners",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DetachLoadBalancerFromSubnets",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancerPolicies",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
      "iam:CreateServiceLinkedRole",
      "kms:DescribeKey"

    ]
  }
}

data "aws_iam_policy_document" "s3-transit" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:GetObject",
      "s3:GetObjectAcl",
      "s3:DeleteObject",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload"

    ]
    resources = [data.aws_s3_bucket.transit.arn, "${data.aws_s3_bucket.transit.arn}/*"]
  }
}
