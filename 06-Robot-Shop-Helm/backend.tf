# =============================================
# BACKEND CONFIGURATION - Step 6: Robot Shop Helm
# =============================================
terraform {
  backend "local" {
    path = "../terraform-states/step6-robot-shop.tfstate"
  }
}
