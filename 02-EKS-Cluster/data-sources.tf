# =============================================
# DATA SOURCES - Reading State from VPC Folder
# =============================================
# WHAT: Reads the state file created by 01-VPC-Networking folder
# WHY: We need VPC ID, Subnet IDs to create the EKS cluster
# HOW: Uses terraform_remote_state to read outputs from the VPC state file
#
# DEPENDENCY CHAIN: 01-VPC-Networking → 02-EKS-Cluster
# This folder DEPENDS on VPC folder being applied first!

data "terraform_remote_state" "vpc" {
  backend = "local"

  config = {
    # Path to the VPC state file (created by 01-VPC-Networking)
    path = "../terraform-states/step1-vpc.tfstate"
  }
}

# =============================================
# LOCAL VALUES - Extracted from VPC State
# =============================================
# WHAT: Creates easy-to-use local variables from the VPC state outputs
# WHY: Instead of typing data.terraform_remote_state.vpc.outputs.xyz everywhere,
#      we can just use local.xyz - cleaner and easier to read!

locals {
  # VPC Information
  vpc_id             = data.terraform_remote_state.vpc.outputs.vpc_id
  public_subnet_ids  = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  private_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  
  # Cluster Information
  cluster_name = data.terraform_remote_state.vpc.outputs.cluster_name
  aws_region   = data.terraform_remote_state.vpc.outputs.region
}
