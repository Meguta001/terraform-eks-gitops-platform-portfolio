
variable "project_name" {
  description = "Project name"
  type        = string
  default     = "eks-gitops-platform"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}


variable "eks_admin_principal_arn" {
  description = "IAM role ARN for EKS administration"
  type        = string
}

variable "eks_public_access_cidrs" {
  description = "Allowed public CIDRs for EKS API"
  type        = list(string)
}
