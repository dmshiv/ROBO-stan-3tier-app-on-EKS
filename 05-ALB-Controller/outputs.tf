# =============================================
# OUTPUTS
# =============================================

output "alb_controller_role_arn" {
  description = "ARN of the IAM role used by ALB Controller"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "alb_controller_policy_arn" {
  description = "ARN of the IAM policy for ALB Controller"
  value       = aws_iam_policy.aws_load_balancer_controller.arn
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

output "vpc_id" {
  description = "VPC ID"
  value       = local.vpc_id
}

output "region" {
  description = "AWS region"
  value       = local.aws_region
}
