
module "ecr" {
  source = "../../../modules/ecr"

  repository_name = "eks-gitops-platform-dev-app"

  tags = {
    Component = "container-registry"
  }
}
