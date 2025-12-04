# =============================================
# OUTPUTS
# =============================================

output "ebs_csi_driver_role_arn" {
  description = "ARN of the IAM role used by EBS CSI Driver"
  value       = aws_iam_role.ebs_csi_driver.arn
}

output "ebs_csi_addon_version" {
  description = "Version of the EBS CSI Driver addon"
  value       = aws_eks_addon.ebs_csi_driver.addon_version
}

output "storage_class_name" {
  description = "Name of the default storage class"
  value       = kubernetes_storage_class.gp3.metadata[0].name
}

# Pass through values
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
