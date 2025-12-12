# =============================================
# OUTPUTS
# =============================================

output "namespace" {
  description = "Kubernetes namespace where Robot Shop is deployed"
  value       = kubernetes_namespace.robot_shop.metadata[0].name
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = local.cluster_name
}

output "region" {
  description = "AWS region"
  value       = local.aws_region
}

output "instructions" {
  description = "Instructions to get the ALB URL"
  value       = <<-EOT
    
    To get the Robot Shop URL, run:
    
    kubectl get ingress robot-shop-ingress -n robot-shop -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
    
    Or check the file: alb-url.txt
    
  EOT
}
