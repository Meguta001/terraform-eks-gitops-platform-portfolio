provider "aws" {
  region = "ap-northeast-1"

  default_tags {
    tags = {
      Project     = "eks-gitops-platform"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}