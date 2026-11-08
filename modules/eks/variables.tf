
variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.36"
}

variable "admin_principal_arn" {
  description = "IAM role ARN for EKS cluster administration"
  type        = string
}

variable "public_access_cidrs" {
  description = "Allowed CIDRs for public EKS API access"
  type        = list(string)
}

variable "node_instance_types" {
  description = "EC2 instance types for managed nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS"
  type        = list(string)
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 3
}
