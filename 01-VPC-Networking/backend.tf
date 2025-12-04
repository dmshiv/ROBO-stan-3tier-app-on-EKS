# =============================================
# BACKEND CONFIGURATION - Step 1: VPC Networking
# =============================================
# WHAT: Tells Terraform WHERE to save the "memory" of what it created
# WHY: Other folders (EKS, NodeGroup) need to READ this state file 
#      to get VPC ID, Subnet IDs, etc.
# HOW: Saves state to a local file that other folders will reference

terraform {
  backend "local" {
    # State file path - other folders will read from this location
    # Think of it as: "Save my work in this file so others can see it"
    path = "../terraform-states/step1-vpc.tfstate"
  }
}
