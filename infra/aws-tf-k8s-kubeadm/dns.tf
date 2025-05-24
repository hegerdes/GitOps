data "aws_route53_zone" "k8s" {
  name = "123-preview.com"
}

resource "aws_route53_record" "k8s" {
  zone_id = data.aws_route53_zone.k8s.zone_id
  name    = local.name
  type    = "CNAME"
  ttl     = "300"
  records = [module.cp_lb.dns_name]
}
