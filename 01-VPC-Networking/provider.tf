# =============================================
# PROVIDER CONFIGURATION - AWS Setup
# =============================================
# WHAT: Tells Terraform which cloud provider to use and how to connect
# WHY: Terraform needs to know WHERE to create resources (AWS, in eu-central-1)
# HOW: Uses your AWS credentials from ~/.aws/credentials or environment variables

terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Provider - This is like telling Terraform:
# "Hey, I want to create resources in AWS, specifically in Frankfurt (eu-central-1)"
provider "aws" {
  region = var.aws_region
  
  # Default tags applied to ALL resources created by this provider
  # Think of it as: "Put these labels on everything I create"
  default_tags {
    tags = {
      Project     = "Robot-Shop-EKS"
      Environment = "Development"
      ManagedBy   = "Terraform"
      Owner       = "DevOps-Team"
    }
  }
}
