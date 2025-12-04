# =============================================
# EKS CLUSTER - The Kubernetes Control Plane
# =============================================
# WHAT THIS FILE DOES:
# Creates the EKS cluster (the "brain" of Kubernetes) and sets up
# secure access so both AWS and you can manage it.
#
# WHY IT'S NEEDED:
# EKS is AWS's managed Kubernetes service. This file creates the control plane
# (the brain) that manages all your worker nodes and pods.
#
# COMPONENTS CREATED:
# 1. IAM Role for EKS - Permission for AWS to manage cluster
# 2. Security Group - Firewall for the cluster
# 3. EKS Cluster - The actual Kubernetes control plane
# 4. OIDC Provider - Enables IRSA (pods can use AWS permissions securely)
#
# ANALOGY:
# Think of EKS as a hotel management company:
# - IAM Role = Business license to operate
# - Security Group = Hotel security system
# - EKS Cluster = The hotel headquarters (manages all branches)
# - OIDC Provider = Guest ID verification system (for room service)


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 1. IAM ROLE FOR EKS CLUSTER                                                    ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Creates an AWS identity (role) that the EKS service uses
# WHY: EKS needs AWS permissions to create/manage resources on your behalf
#      (create network interfaces, manage CloudWatch logs, etc.)
# DOES: Says "the eks.amazonaws.com service can use this role"

resource "aws_iam_role" "eks_cluster" {
  name = "${local.cluster_name}-cluster-role"

  # Assume Role Policy: "Who can wear this identity badge?"
  # Answer: Only the EKS service (eks.amazonaws.com)
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 2. ATTACH POLICIES TO EKS CLUSTER ROLE                                         ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Attaches AWS-managed policies to the EKS role
# WHY: The role needs specific permissions to manage the cluster
# DOES: Gives EKS permission to create ENIs, manage logs, etc.

# Policy 1: AmazonEKSClusterPolicy
# Gives EKS permissions to manage cluster resources
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# Policy 2: AmazonEKSVPCResourceController
# Allows EKS to manage VPC resources (ENIs for pod networking)
resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 3. SECURITY GROUP FOR EKS CLUSTER                                              ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Creates a firewall that controls traffic to/from the EKS control plane
# WHY: Security! We need to control what can talk to the Kubernetes API server
# DOES: Allows all outbound traffic (so EKS can talk to AWS services)

resource "aws_security_group" "eks_cluster" {
  name        = "${local.cluster_name}-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = local.vpc_id

  # Egress: Allow ALL outbound traffic
  # EKS needs to communicate with AWS services (EC2, ECR, CloudWatch, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # -1 means ALL protocols
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.cluster_name}-cluster-sg"
    }
  )
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 4. THE EKS CLUSTER - THE MAIN EVENT!                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Creates the actual Kubernetes control plane managed by AWS
# WHY: This is the brain of your Kubernetes cluster!
#      - API Server (receives kubectl commands)
#      - Scheduler (decides where pods run)
#      - Controller Manager (maintains desired state)
#      - etcd (stores all cluster data)
# DOES: Creates EKS cluster with both public and private API access

resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  # VPC Configuration
  # Where the cluster lives and how it's accessed
  vpc_config {
    # Subnets: Place control plane ENIs in both public and private subnets
    # This gives high availability across multiple AZs
    subnet_ids = concat(local.public_subnet_ids, local.private_subnet_ids)
    
    # Private Access: Allow kubectl from within VPC
    endpoint_private_access = true
    
    # Public Access: Allow kubectl from your laptop (via internet)
    endpoint_public_access  = true
    
    # Security Groups: Attach our custom security group
    security_group_ids = [aws_security_group.eks_cluster.id]
  }

  # Enable Control Plane Logging
  # Sends logs to CloudWatch for troubleshooting
  enabled_cluster_log_types = [
    "api",              # API server logs (kubectl commands)
    "audit",            # Who did what (security audit)
    "authenticator",    # Authentication events
    "controllerManager", # Controller activities
    "scheduler"         # Pod scheduling decisions
  ]

  # DEPENDENCY: Wait for IAM policies to be attached first!
  # EKS creation will fail if the role doesn't have permissions yet
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]

  tags = var.tags
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 5. OIDC PROVIDER - THE SECRET SAUCE FOR IRSA!                                  ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Creates an OpenID Connect identity provider in AWS IAM
# WHY: This enables IRSA (IAM Roles for Service Accounts)!
#      - Pods can securely use AWS permissions without hardcoded credentials
#      - ALB Controller needs this to create load balancers
#      - EBS CSI Driver needs this to create volumes
# DOES: Establishes trust between Kubernetes service accounts and AWS IAM roles
#
# ANALOGY: Setting up a secure ID verification system
# - Without IRSA: Give every hotel guest (pod) a master key (AWS credentials) - DANGEROUS!
# - With IRSA: Each guest gets a personalized keycard that only opens their room - SECURE!

# Step 5a: Get the TLS certificate from EKS OIDC endpoint
# This is needed to establish trust between AWS and Kubernetes
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# Step 5b: Register the OIDC provider with AWS IAM
# Now AWS will trust tokens issued by this EKS cluster
resource "aws_iam_openid_connect_provider" "eks" {
  # Client ID: Who can use this OIDC provider
  # "sts.amazonaws.com" = AWS STS service (for assuming roles)
  client_id_list  = ["sts.amazonaws.com"]
  
  # Thumbprint: Certificate fingerprint for verification
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  
  # URL: The OIDC issuer URL from our EKS cluster
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = var.tags
}
