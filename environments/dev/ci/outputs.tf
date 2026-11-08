
output "github_oidc_provider_arn" {
  description = "GitHub OIDC Provider ARN"
  value       = module.github_oidc.oidc_provider_arn
}

output "github_actions_role_arn" {
  description = "GitHub Actions IAM Role ARN"
  value       = module.github_oidc.github_actions_role_arn
}
