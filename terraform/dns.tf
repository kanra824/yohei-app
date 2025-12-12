# --- Route 53 Hosted Zone (既存のものをインポート) -----------------------
data "aws_route53_zone" "main" {
  name = "kanra824.com"
}

# --- ACM Certificate -------------------------------------------------------
resource "aws_acm_certificate" "main" {
  domain_name       = "kanra824.com"
  validation_method = "DNS"

  subject_alternative_names = [
    "www.kanra824.com"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "kanra824.com"
  }
}

# --- ACM Certificate Validation Records ------------------------------------
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# --- ACM Certificate Validation --------------------------------------------
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# --- Route 53 A Record (kanra824.com → ALB) --------------------------------
resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "kanra824.com"
  type    = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

# --- Route 53 A Record (www.kanra824.com → ALB) ----------------------------
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www.kanra824.com"
  type    = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}
