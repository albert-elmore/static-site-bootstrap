output "site_bucket_name" {
  description = "S3 bucket where you should upload the website files."
  value       = aws_s3_bucket.site.bucket
}

output "cloudfront_domain_name" {
  description = "The CloudFront domain name (useful for testing before DNS propagates)."
  value       = aws_cloudfront_distribution.site.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (use in deploy.sh for cache invalidation)."
  value       = aws_cloudfront_distribution.site.id
}

output "acm_certificate_arn" {
  description = "ARN of the validated ACM certificate in us-east-1."
  value       = aws_acm_certificate_validation.cert.certificate_arn
}