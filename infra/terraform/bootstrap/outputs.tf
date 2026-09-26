output "state_bucket_name" {
  description = "Put this in the backend block of infra/terraform (backend/<env>.s3.tfbackend)."
  value       = aws_s3_bucket.state.bucket
}
