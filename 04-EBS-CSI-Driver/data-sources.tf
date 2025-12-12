# =============================================
# DATA SOURCES - Reading State from Previous Folders
# =============================================
# DEPENDENCY CHAIN: 01-VPC → 02-EKS → 03-NodeGroup → 04-EBS-CSI

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

# Get AWS account ID (needed for IAM role ARN)
data "aws_caller_identity" "current" {}

# =============================================
# LOCAL VALUES
# =============================================
locals {
  cluster_name       = data.terraform_remote_state.eks.outputs.cluster_name
  cluster_endpoint   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_data    = data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data
  oidc_provider_arn  = data.terraform_remote_state.eks.outputs.oidc_provider_arn
  oidc_provider_url  = data.terraform_remote_state.eks.outputs.oidc_provider_url
  aws_region         = data.terraform_remote_state.eks.outputs.region
  aws_account_id     = data.aws_caller_identity.current.account_id
}
