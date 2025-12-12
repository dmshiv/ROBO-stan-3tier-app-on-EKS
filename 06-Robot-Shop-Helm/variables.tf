# =============================================
# VARIABLES
# =============================================

variable "robot_shop_namespace" {
  description = "Kubernetes namespace for Robot Shop application"
  type        = string
  default     = "robot-shop"
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
