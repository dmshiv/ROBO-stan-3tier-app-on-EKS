# =============================================
# OUTPUTS - Values Exported for Other Folders
# =============================================
# These outputs are READ by:
# - 03-EC2-NodeGroup (needs cluster info to join nodes)
# - 04-EBS-CSI-Driver (needs OIDC for IRSA)
# - 05-ALB-Controller (needs cluster and OIDC info)
# - 06-Robot-Shop-Helm (needs cluster endpoint for kubectl)

# ----------------------------------------------
# CLUSTER OUTPUTS
# ----------------------------------------------
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint URL for the EKS cluster API server"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_version" {
  description = "Kubernetes version of the cluster"
  value       = aws_eks_cluster.main.version
}

# ----------------------------------------------
# OIDC OUTPUTS - Critical for IRSA!
# ----------------------------------------------
output "oidc_provider_arn" {
  description = "ARN of the OIDC provider - needed for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider (without https://)"
  value       = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

output "oidc_issuer" {
  description = "OIDC issuer URL of the cluster"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# ----------------------------------------------
# SECURITY GROUP OUTPUT
# ----------------------------------------------
output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.eks_cluster.id
}

# ----------------------------------------------
# NETWORK OUTPUTS (passed through from VPC)
# ----------------------------------------------
output "vpc_id" {
  description = "VPC ID where cluster is deployed"
  value       = local.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (for worker nodes)"
  value       = local.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs (for load balancers)"
  value       = local.public_subnet_ids
}

output "region" {
  description = "AWS region"
  value       = local.aws_region
}
