# =============================================
# DATA SOURCES - Reading State from Previous Folders
# =============================================
# DEPENDENCY CHAIN: 01-VPC → 02-EKS → 03-NodeGroup → 04-EBS-CSI → 05-ALB

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

data "terraform_remote_state" "nodegroup" {
  backend = "local"
  config = {
    path = "../terraform-states/step3-nodegroup.tfstate"
  }
}

data "terraform_remote_state" "ebs_csi" {
  backend = "local"
  config = {
    path = "../terraform-states/step4-ebs-csi.tfstate"
  }
}

# =============================================
# LOCAL VALUES
# =============================================
locals {
  cluster_name       = data.terraform_remote_state.eks.outputs.cluster_name
  cluster_endpoint   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_data    = data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data
  oidc_provider_arn  = data.terraform_remote_state.eks.outputs.oidc_provider_arn
  oidc_provider_url  = data.terraform_remote_state.eks.outputs.oidc_provider_url
  vpc_id             = data.terraform_remote_state.vpc.outputs.vpc_id
  aws_region         = data.terraform_remote_state.eks.outputs.region
}
