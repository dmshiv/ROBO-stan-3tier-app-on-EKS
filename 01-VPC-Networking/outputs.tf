# =============================================
# OUTPUTS - Values Exported for Other Folders
# =============================================
# WHAT: These are the "return values" from this folder
# WHY: Other folders (EKS, NodeGroup) need these values to create their resources
# HOW: They use "terraform_remote_state" data source to read these outputs
#
# Think of outputs as: "Here's what I created, other folders can use these"

# ----------------------------------------------
# VPC OUTPUTS
# ----------------------------------------------
output "vpc_id" {
  description = "The ID of the VPC - needed by EKS, security groups, etc."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

# ----------------------------------------------
# SUBNET OUTPUTS
# ----------------------------------------------
output "public_subnet_ids" {
  description = "List of public subnet IDs - used for Load Balancers"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs - used for EKS worker nodes"
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of private subnets"
  value       = aws_subnet.private[*].cidr_block
}

# ----------------------------------------------
# GATEWAY OUTPUTS
# ----------------------------------------------
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

# ----------------------------------------------
# CLUSTER INFO (passed through for consistency)
# ----------------------------------------------
output "cluster_name" {
  description = "Name of the EKS cluster (used for tagging and naming)"
  value       = var.cluster_name
}

output "region" {
  description = "AWS region where resources are created"
  value       = var.aws_region
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = var.availability_zones
}
