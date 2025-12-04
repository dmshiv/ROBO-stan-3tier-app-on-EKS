# =============================================
# VARIABLES - Configurable Values for VPC
# =============================================
# WHAT: Input parameters that can be changed without modifying main code
# WHY: Makes the code reusable - just change variables, not the actual code
# HOW: Define variables here, use them in vpc.tf with var.variable_name

# ----------------------------------------------
# REGION CONFIGURATION
# ----------------------------------------------
# Which AWS region to deploy in
# eu-central-1 = Frankfurt, Germany (chosen for this project)
variable "aws_region" {
  description = "AWS region where all resources will be created"
  type        = string
  default     = "eu-central-1"
}

# ----------------------------------------------
# CLUSTER NAME
# ----------------------------------------------
# Name for the EKS cluster - used in tags and resource names
# This name will be used by VPC tags so EKS can discover the VPC later
variable "cluster_name" {
  description = "Name of the EKS cluster - used for tagging and naming resources"
  type        = string
  default     = "robot-shop-eks-cluster"
}

# ----------------------------------------------
# VPC NETWORK CONFIGURATION
# ----------------------------------------------
# CIDR = IP address range for the VPC
# 10.0.0.0/16 gives us 65,536 IP addresses to work with
# Think of it as: "This is the size of our private network"
variable "vpc_cidr" {
  description = "CIDR block for the VPC - defines the IP address range"
  type        = string
  default     = "10.0.0.0/16"
}

# ----------------------------------------------
# PUBLIC SUBNETS
# ----------------------------------------------
# Public subnets are for resources that need direct internet access
# Used for: Load Balancers, NAT Gateways, Bastion hosts
# We create 2 subnets in different Availability Zones for high availability
variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (internet-facing resources)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

# ----------------------------------------------
# PRIVATE SUBNETS
# ----------------------------------------------
# Private subnets are for resources that should NOT have direct internet access
# Used for: EKS worker nodes, Databases, Application servers
# Traffic goes out via NAT Gateway (one-way internet access)
variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (internal resources like worker nodes)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

# ----------------------------------------------
# AVAILABILITY ZONES
# ----------------------------------------------
# AWS data centers in the region - we use 2 for redundancy
# If one AZ goes down, our app still runs in the other!
variable "availability_zones" {
  description = "List of availability zones to use for subnets"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

# ----------------------------------------------
# COMMON TAGS
# ----------------------------------------------
# Labels attached to all resources for organization and cost tracking
variable "tags" {
  description = "Common tags applied to all resources for organization"
  type        = map(string)
  default = {
    Project     = "Robot-Shop-EKS"
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}
