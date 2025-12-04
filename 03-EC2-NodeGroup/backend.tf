# =============================================
# BACKEND CONFIGURATION - Step 3: EC2 NodeGroup
# =============================================
# WHAT: Tells Terraform WHERE to save the state for this folder
# WHY: Other folders need to know worker nodes are ready
# HOW: Saves to a local file that other folders will reference

terraform {
  backend "local" {
    path = "../terraform-states/step3-nodegroup.tfstate"
  }
}
