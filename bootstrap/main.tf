locals {
  backend_bucket_name = var.backend_bucket_name
}

# S3 bucket for storing the development environment's Terraform state.
resource "aws_s3_bucket" "terraform_state" {
  bucket        = local.backend_bucket_name
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

# Keep old state object versions for recovery after accidental changes.
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Explicitly require SSE-S3 for data stored in the bucket.
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Prevent public access at the bucket level.
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Disable ACL-based object ownership management.
resource "aws_s3_bucket_ownership_controls" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
