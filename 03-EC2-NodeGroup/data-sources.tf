# =============================================
# DATA SOURCES - Reading State from Previous Folders
# =============================================
# WHAT: Reads state files from VPC and EKS folders
# WHY: We need VPC subnets and EKS cluster info to create worker nodes
# DEPENDENCY CHAIN: 01-VPC → 02-EKS → 03-EC2-NodeGroup

data "terraform_remote_state" "vpc" {
  backend = "local"

  config = {
    path = "../terraform-states/step1-vpc.tfstate"
  }
}

data "terraform_remote_state" "eks" {
  backend = "local"

  config = {
    path = "../terraform-states/step2-eks.tfstate"
  }
}

# =============================================
# LOCAL VALUES - Easy Access to Previous Outputs
# =============================================
locals {
  # From VPC
  vpc_id             = data.terraform_remote_state.vpc.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  
  # From EKS
  cluster_name              = data.terraform_remote_state.eks.outputs.cluster_name
  cluster_endpoint          = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_data           = data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data
  cluster_security_group_id = data.terraform_remote_state.eks.outputs.cluster_security_group_id
  aws_region                = data.terraform_remote_state.eks.outputs.region
}
