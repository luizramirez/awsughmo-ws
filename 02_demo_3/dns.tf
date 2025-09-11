resource "aws_route53_record" "dogo" {
  zone_id = "Z09771163UON58AA7HJAT"
  name    = "dogo.zahuaro.com.mx"
  type    = "CNAME"
  ttl     = 300
  records = [aws_s3_bucket_website_configuration.site.website_endpoint]
}

output "cname" {
    value = aws_route53_record.dogo.fqdn
}