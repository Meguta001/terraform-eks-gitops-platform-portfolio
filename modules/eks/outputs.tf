
output "cluster_role_arn" {
  description = "EKS Cluster IAM role ARN"
  value       = aws_iam_role.cluster.arn
}

output "node_role_arn" {
  description = "EKS Node IAM role ARN"
  value       = aws_iam_role.node.arn
}


output "cluster_name" {
  description = "EKS Cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS Kubernetes API endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS Cluster CA data"
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "node_group_name" {
  description = "EKS Managed Node Group name"
  value       = aws_eks_node_group.this.node_group_name
}
