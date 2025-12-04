# =============================================
# BACKEND CONFIGURATION - Step 4: EBS CSI Driver
# =============================================
terraform {
  backend "local" {
    path = "../terraform-states/step4-ebs-csi.tfstate"
  }
}
