# =============================================
# VARIABLES
# =============================================

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "Robot-Shop-EKS"
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}
