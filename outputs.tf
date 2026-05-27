output "nameservers" {
  description = "Paste these 4 nameservers into Namecheap DNS settings"
  value       = aws_route53_zone.primary.name_servers
}

output "cloudfront_url" {
  description = "Raw CloudFront distribution URL"
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}

output "live_site_url" {
  description = "Your live portfolio site on your custom domain"
  value       = "https://${var.domain_name}"
}

output "www_site_url" {
  description = "WWW version of your live site"
  value       = "https://www.${var.domain_name}"
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate attached to CloudFront"
  value       = aws_acm_certificate.cert.arn
}

output "s3_bucket_name" {
  description = "Name of the primary S3 bucket hosting your site"
  value       = aws_s3_bucket.website.id
}