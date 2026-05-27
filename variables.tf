variable "aws_region" {
  description = "Primary AWS region for S3 and Route 53"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Root domain name registered on Namecheap"
  type        = string
  default     = "tenglee.dev"
}

variable "bucket_name" {
  description = "S3 bucket name for static hosting"
  type        = string
  default     = "tenglee.dev"
}

variable "www_bucket_name" {
  description = "S3 bucket for www subdomain redirect"
  type        = string
  default     = "www.tenglee.dev"
}