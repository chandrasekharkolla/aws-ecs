output "acm_details" {
  value     = aws_acm_certificate.certs
  sensitive = true
}

output "cert_dns_details" {
  value     = aws_route53_record.cert_dnss
  sensitive = true
}
