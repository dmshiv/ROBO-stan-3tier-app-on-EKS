# =============================================
# BACKEND CONFIGURATION - Step 2: EKS Cluster
# =============================================
# WHAT: Tells Terraform WHERE to save the state for this folder
# WHY: NodeGroup, ALB Controller need to read EKS cluster details from this state
# HOW: Saves to a local file that other folders will reference

terraform {
  backend "local" {
    # State file path - other folders will read from this location
    path = "../terraform-states/step2-eks.tfstate"
  }
}
