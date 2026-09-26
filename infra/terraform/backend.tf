# -----------------------------------------------------------------------------
# Remote state (S3, native lock file). DISABLED until you run the bootstrap.
#
# 1. Create the state bucket once per AWS account:
#      cd infra/terraform/bootstrap
#      terraform init && terraform apply -var="state_bucket_name=carecompanion-tfstate-<account-id>"
# 2. Uncomment the block below (leave the values out; they come from a file).
# 3. Create backend/<env>.s3.tfbackend (not committed if you prefer) with:
#      bucket       = "carecompanion-tfstate-<account-id>"
#      key          = "carecompanion/<env>/terraform.tfstate"   # one key per environment
#      region       = "ap-south-1"
#      encrypt      = true
#      use_lockfile = true
# 4. cd infra/terraform && terraform init -backend-config=backend/<env>.s3.tfbackend
#    (switching environments: terraform init -reconfigure -backend-config=backend/<other>.s3.tfbackend)
#
# State contains resource metadata (no secret VALUES: RDS manages its own master
# password and Secrets Manager values are set out-of-band), but treat it as
# sensitive anyway: the bucket is private, versioned and KMS-encrypted.
# -----------------------------------------------------------------------------

# terraform {
#   backend "s3" {}
# }
