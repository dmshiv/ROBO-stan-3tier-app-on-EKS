# =============================================
# OUTPUTS - Values Exported for Other Folders
# =============================================

output "node_group_name" {
  description = "Name of the EKS node group"
  value       = aws_eks_node_group.main.node_group_name
}

output "node_group_arn" {
  description = "ARN of the EKS node group"
  value       = aws_eks_node_group.main.arn
}

output "node_group_status" {
  description = "Status of the node group"
  value       = aws_eks_node_group.main.status
}

output "node_role_arn" {
  description = "ARN of the IAM role used by worker nodes"
  value       = aws_iam_role.node_group.arn
}

output "node_security_group_id" {
  description = "Security group ID for worker nodes"
  value       = aws_security_group.node_group.id
}

# Pass through values from previous states
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = local.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint of the EKS cluster"
  value       = local.cluster_endpoint
}

output "region" {
  description = "AWS region"
  value       = local.aws_region
}
