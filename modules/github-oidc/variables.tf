
variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name"
  type        = string
}

variable "github_owner_id" {
  description = "Immutable GitHub owner ID"
  type        = string
}

variable "github_repository_id" {
  description = "Immutable GitHub repository ID"
  type        = string
}

variable "github_branch" {
  description = "Allowed GitHub branch"
  type        = string
  default     = "main"
}

variable "ecr_repository_arn" {
  description = "ECR repository ARN for image push"
  type        = string
}
