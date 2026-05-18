variable "region" {
  description = "AWS region for S3 and Route 53. ACM certificates for CloudFront must be in us-east-1 (handled automatically)."
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Root domain for the site (e.g. example.com). A public Route 53 hosted zone for this domain must already exist."
  type        = string
}

variable "site_bucket_name" {
  description = "Globally unique S3 bucket name for website files (e.g. example-com-site)."
  type        = string
}
