# =============================================
# PROVIDER CONFIGURATION - AWS Setup
# =============================================
# WHAT: Tells Terraform which cloud provider to use and how to connect
# WHY: Terraform needs to know WHERE to create resources

terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = local.aws_region
  
  default_tags {
    tags = {
      Project     = "Robot-Shop-EKS"
      Environment = "Development"
      ManagedBy   = "Terraform"
      Owner       = "DevOps-Team"
    }
  }
}
