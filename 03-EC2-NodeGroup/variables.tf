# =============================================
# VARIABLES - Configurable Values for EC2 NodeGroup
# =============================================

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.medium"  # Good balance of CPU/Memory for Robot Shop
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "node_disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 30  # 30GB for Docker images and logs
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
