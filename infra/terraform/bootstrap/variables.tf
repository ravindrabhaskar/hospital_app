variable "region" {
  description = "AWS region for the state bucket. Mumbai keeps everything in India."
  type        = string
  default     = "ap-south-1"
}

variable "state_bucket_name" {
  description = "Globally unique name of the Terraform state bucket, e.g. carecompanion-tfstate-123456789012."
  type        = string
}
