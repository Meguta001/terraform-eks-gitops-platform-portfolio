data "aws_caller_identity" "current" {}

module "github_oidc" {
  source = "../../../modules/github-oidc"

  github_owner      = "YOUR_GITHUB_OWNER"
  github_repository = "YOUR_GITHUB_REPOSITORY"

  github_owner_id      = "YOUR_GITHUB_OWNER_ID"
  github_repository_id = "YOUR_GITHUB_REPOSITORY_ID"

  github_branch = "main"

  ecr_repository_arn = "arn:aws:ecr:ap-northeast-1:${data.aws_caller_identity.current.account_id}:repository/eks-gitops-platform-dev-app"
}
