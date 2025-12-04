# =============================================
# VARIABLES - Configurable Values for EKS Cluster
# =============================================

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "Robot-Shop-EKS"
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}
