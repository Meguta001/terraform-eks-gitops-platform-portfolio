
# Backend operation verification resource.
# Does not create any AWS infrastructure.

resource "terraform_data" "backend_verification" {
  input = {
    environment = "dev"
    purpose     = "verify-s3-remote-state"
  }
}

module "network" {
  source = "../../modules/network"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = "10.20.0.0/16"

  public_subnets = {
    a = {
      cidr_block        = "10.20.0.0/24"
      availability_zone = "ap-northeast-1a"
    }
    c = {
      cidr_block        = "10.20.1.0/24"
      availability_zone = "ap-northeast-1c"
    }
  }

  private_subnets = {
    a = {
      cidr_block        = "10.20.16.0/20"
      availability_zone = "ap-northeast-1a"
    }
    c = {
      cidr_block        = "10.20.32.0/20"
      availability_zone = "ap-northeast-1c"
    }
  }
}


module "eks" {
  source = "../../modules/eks"

  project_name = var.project_name
  environment  = var.environment

  private_subnet_ids = values(module.network.private_subnet_ids)

  admin_principal_arn = var.eks_admin_principal_arn
  public_access_cidrs = var.eks_public_access_cidrs

  # NAT Gateway・Private Routeの完成を待つ
  depends_on = [module.network]
}
