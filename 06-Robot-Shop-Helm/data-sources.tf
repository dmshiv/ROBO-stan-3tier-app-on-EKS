# =============================================
# DATA SOURCES - Reading State from Previous Folders
# =============================================
# DEPENDENCY CHAIN: All previous folders → 06-Robot-Shop

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

data "terraform_remote_state" "alb" {
  backend = "local"
  config = {
    path = "../terraform-states/step5-alb-controller.tfstate"
  }
}

# =============================================
# LOCAL VALUES
# =============================================
locals {
  cluster_name       = data.terraform_remote_state.eks.outputs.cluster_name
  cluster_endpoint   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_data    = data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data
  vpc_id             = data.terraform_remote_state.vpc.outputs.vpc_id
  public_subnet_ids  = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  aws_region         = data.terraform_remote_state.eks.outputs.region
}
