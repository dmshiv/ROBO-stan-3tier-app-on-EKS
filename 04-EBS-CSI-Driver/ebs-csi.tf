# =============================================
# EBS CSI DRIVER - Persistent Storage for Pods
# =============================================
# WHAT THIS FILE DOES:
# Installs the AWS EBS CSI (Container Storage Interface) Driver into your cluster.
# This allows Kubernetes to create and manage EBS volumes for your pods.
#
# WHY IT'S NEEDED:
# Robot Shop has databases (MongoDB, MySQL, Redis) that need PERSISTENT storage!
# Without EBS CSI Driver:
#   - If a pod restarts, all data is LOST!
#   - Databases would be useless
# With EBS CSI Driver:
#   - Kubernetes can create EBS volumes automatically
#   - Data survives pod restarts and even node failures
#   - Databases keep their data safe!
#
# COMPONENTS CREATED:
# 1. IAM Role for EBS CSI Driver (using IRSA)
# 2. EKS Addon for EBS CSI Driver
# 3. StorageClass for dynamic volume provisioning
#
# ANALOGY:
# Think of EBS CSI Driver as a "USB drive manager":
# - Before: Containers are like whiteboards - erase when you're done
# - After: Containers can save to USB drives (EBS) that persist forever


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 1. IAM ROLE FOR EBS CSI DRIVER (IRSA)                                          ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Creates an IAM role that the EBS CSI Driver pods can use
# WHY: The driver needs AWS permissions to create/attach/delete EBS volumes
# DOES: Uses IRSA (IAM Roles for Service Accounts) - secure, no hardcoded credentials!

# Trust Policy: "Who can use this role?"
# Answer: Only the ebs-csi-controller-sa service account in kube-system namespace
data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    principals {
      identifiers = [local.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

# Create the IAM Role
resource "aws_iam_role" "ebs_csi_driver" {
  name               = "${local.cluster_name}-ebs-csi-driver-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json

  tags = var.tags
}

# Attach the AWS-managed EBS CSI policy
# This policy gives all permissions needed to manage EBS volumes
resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 2. EKS ADDON - INSTALL EBS CSI DRIVER                                          ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Installs the EBS CSI Driver as an EKS managed addon
# WHY: EKS addons are managed by AWS - automatic updates, tested compatibility!
# DOES: Deploys the driver pods with the IAM role we created

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = local.cluster_name
  addon_name   = "aws-ebs-csi-driver"
  
  # Use the IAM role we created for IRSA
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
  
  # Resolve conflicts by overwriting existing configuration
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_iam_role_policy_attachment.ebs_csi_policy
  ]

  tags = var.tags
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 3. WAIT FOR EBS CSI DRIVER TO BE READY                                         ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Waits until EBS CSI Driver pods are running
# WHY: We can't create volumes until the driver is ready!
# DOES: Polls until driver pods show "Running" status (no time limit)

resource "null_resource" "wait_for_ebs_csi" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "Configuring kubectl for EKS cluster..."
      aws eks update-kubeconfig --region ${local.aws_region} --name ${local.cluster_name}
      
      echo "Waiting for EBS CSI Driver pods to be Ready (no time limit)..."
      
      # Wait for ebs-csi-controller pods to be running
      until kubectl get pods -n kube-system -l app=ebs-csi-controller -o jsonpath='{.items[*].status.phase}' 2>/dev/null | grep -q "Running"; do
        echo "  Waiting for EBS CSI Controller pods..."
        sleep 10
      done
      
      echo ""
      echo "✓✓✓ EBS CSI Driver is Ready!"
      kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver
    EOT
  }

  depends_on = [
    aws_eks_addon.ebs_csi_driver
  ]
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 4. STORAGE CLASS - HOW TO CREATE VOLUMES                                       ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Defines HOW EBS volumes should be created
# WHY: When a pod requests storage, Kubernetes needs to know:
#      - What type of EBS volume? (gp3 = General Purpose SSD)
#      - What size? (dynamic based on request)
#      - Should it be encrypted?
# DOES: Creates a "recipe" for creating EBS volumes

resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  
  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"  # Delete EBS when PVC is deleted
  volume_binding_mode = "WaitForFirstConsumer"  # Wait until pod needs it
  allow_volume_expansion = true  # Can resize volumes later
  
  parameters = {
    type      = "gp3"       # GP3 = modern, cost-effective SSD
    encrypted = "true"      # Encrypt data at rest (security!)
    fsType    = "ext4"      # Linux filesystem
  }

  depends_on = [
    null_resource.wait_for_ebs_csi
  ]
}
