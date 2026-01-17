variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "jenkins-artifact-bucket"
}

variable "versioning_enabled" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
  default     = true
}

variable "region" {
  description = "AWS region for the S3 bucket"
  type        = string
  default     = "us-east-1" 
  
}