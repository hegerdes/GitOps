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

resource "aws_iam_policy" "s3-transit" {
  name        = "s3-transit"
  description = "Store user data for mastodon on s3"
  policy      = data.aws_iam_policy_document.s3-transit.json
  tags        = local.tags
}
resource "aws_iam_policy" "vpc_ec2_ipv6" {
  name        = "vpc-ec2-ipv6"
  description = "Store user data for mastodon on s3"
  policy      = data.aws_iam_policy_document.vpc_ec2_ipv6.json
  tags        = local.tags
}
resource "aws_iam_policy" "vpc_ec2_ipv4" {
  name        = "vpc-ec2-ipv4"
  description = "Store user data for mastodon on s3"
  policy      = data.aws_iam_policy_document.vpc_ec2_ipv4.json
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
