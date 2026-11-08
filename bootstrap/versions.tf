terraform {
  # S3 backend lockfile support is available in Terraform 1.10+.
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Bootstrap manages the bucket used by other root modules.
  # Do not configure this root module to use the bucket it creates.
  # Its state remains local and must be backed up securely.
}
