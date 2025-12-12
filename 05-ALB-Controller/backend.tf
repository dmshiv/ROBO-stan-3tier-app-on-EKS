# =============================================
# BACKEND CONFIGURATION - Step 5: ALB Controller
# =============================================
terraform {
  backend "local" {
    path = "../terraform-states/step5-alb-controller.tfstate"
  }
}
