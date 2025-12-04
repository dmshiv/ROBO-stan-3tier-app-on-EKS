# =============================================
# EC2 NODE GROUP - The Worker Bees of Kubernetes
# =============================================
# WHAT THIS FILE DOES:
# Creates EC2 instances (worker nodes) that run your actual pods/containers.
# The EKS cluster (control plane) tells these nodes what to do.
#
# WHY IT'S NEEDED:
# The EKS cluster is just the "brain" - it needs "hands" (worker nodes) to 
# actually run your applications. Pods are scheduled on these nodes.
#
# COMPONENTS CREATED:
# 1. IAM Role for Worker Nodes - Permission for nodes to talk to AWS
# 2. Security Group for Nodes - Firewall rules for worker nodes
# 3. EKS Node Group - The actual EC2 instances
#
# ANALOGY:
# If EKS Cluster is the Hotel Headquarters (management):
# - Worker Nodes = The actual hotel staff (waiters, housekeeping)
# - They receive instructions from HQ and do the actual work
# - More guests (pods) = HQ tells nodes to hire more staff (scale up)


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 1. IAM ROLE FOR WORKER NODES                                                   ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Creates an AWS identity for the EC2 worker nodes
# WHY: Nodes need permission to:
#      - Register with the EKS cluster
#      - Pull Docker images from ECR
#      - Manage ENIs (network interfaces)
#      - Write logs to CloudWatch
# DOES: Allows ec2.amazonaws.com service to assume this role

resource "aws_iam_role" "node_group" {
  name = "${local.cluster_name}-node-group-role"

  # Assume Role Policy: "Who can wear this identity badge?"
  # Answer: EC2 instances (the worker nodes)
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 2. ATTACH POLICIES TO NODE GROUP ROLE                                          ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Attaches AWS-managed policies to the node role
# WHY: Each policy grants specific permissions needed by worker nodes

# Policy 1: AmazonEKSWorkerNodePolicy
# Lets nodes register with EKS cluster and receive pod specs
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

# Policy 2: AmazonEKS_CNI_Policy
# Lets nodes manage networking (assign IPs to pods)
resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

# Policy 3: AmazonEC2ContainerRegistryReadOnly
# Lets nodes pull Docker images from Amazon ECR
resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

# Policy 4: AmazonSSMManagedInstanceCore
# Lets you connect to nodes via AWS Session Manager (no SSH keys needed!)
resource "aws_iam_role_policy_attachment" "node_AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.node_group.name
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 3. SECURITY GROUP FOR WORKER NODES                                             ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Creates a firewall for worker nodes
# WHY: Controls what traffic can reach the nodes
# DOES: 
#   - Allows all traffic within the security group (pod-to-pod)
#   - Allows control plane to talk to nodes
#   - Allows all outbound traffic

resource "aws_security_group" "node_group" {
  name        = "${local.cluster_name}-node-group-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = local.vpc_id

  # Ingress: Allow all traffic from nodes in the same security group
  # This is needed for pod-to-pod communication!
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow all traffic within the node group"
  }

  # Ingress: Allow control plane to communicate with nodes
  # The EKS cluster needs to send instructions to nodes
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [local.cluster_security_group_id]
    description     = "Allow HTTPS from cluster control plane"
  }

  # Ingress: Allow control plane to reach kubelet
  ingress {
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [local.cluster_security_group_id]
    description     = "Allow kubelet API from control plane"
  }

  # Egress: Allow ALL outbound traffic
  # Nodes need to pull images, talk to AWS APIs, etc.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.cluster_name}-node-group-sg"
      "kubernetes.io/cluster/${local.cluster_name}" = "owned"
    }
  )
}

# Allow cluster security group to receive traffic from nodes
resource "aws_security_group_rule" "cluster_inbound_from_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node_group.id
  security_group_id        = local.cluster_security_group_id
  description              = "Allow worker nodes to communicate with cluster API"
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 4. EKS NODE GROUP - THE ACTUAL WORKER NODES!                                   ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Creates managed EC2 instances that join the EKS cluster as worker nodes
# WHY: These nodes are where your pods (containers) actually run!
# DOES:
#   - Creates EC2 instances with the specified type (t3.medium)
#   - Automatically joins them to the EKS cluster
#   - Auto-scaling: min 2, desired 2, max 4 nodes
#   - Places nodes in private subnets (secure!)

resource "aws_eks_node_group" "main" {
  cluster_name    = local.cluster_name
  node_group_name = "${local.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.node_group.arn
  
  # Place nodes in PRIVATE subnets (not directly accessible from internet)
  subnet_ids = local.private_subnet_ids

  # Instance Configuration
  instance_types = [var.node_instance_type]
  disk_size      = var.node_disk_size
  
  # Use Amazon Linux 2 optimized for EKS
  ami_type = "AL2_x86_64"
  
  # Use the latest EKS-optimized AMI
  capacity_type = "ON_DEMAND"

  # Scaling Configuration
  # How many nodes? Start with desired, can scale between min and max
  scaling_config {
    desired_size = var.node_desired_size  # Start with 2 nodes
    min_size     = var.node_min_size      # Never go below 2
    max_size     = var.node_max_size      # Never exceed 4
  }

  # Update Configuration
  # How to update nodes? One at a time to avoid downtime
  update_config {
    max_unavailable = 1  # Only update 1 node at a time
  }

  # Labels: Metadata attached to nodes
  # Useful for scheduling pods to specific nodes
  labels = {
    "role"        = "worker"
    "environment" = "development"
  }

  # DEPENDENCY: Wait for IAM policies to be attached!
  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_AmazonSSMManagedInstanceCore,
  ]

  tags = var.tags

  # Lifecycle: Ignore changes to desired_size (let autoscaler manage it)
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 5. WAIT FOR NODES TO BE READY                                                  ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Waits until all nodes are Ready and can accept pods
# WHY: Next steps (EBS CSI, ALB Controller) need working nodes
# DOES: Polls kubectl until nodes show "Ready" status (no time limit!)

resource "null_resource" "wait_for_nodes" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "Configuring kubectl for EKS cluster..."
      aws eks update-kubeconfig --region ${local.aws_region} --name ${local.cluster_name}
      
      echo "Waiting for worker nodes to be Ready (no time limit)..."
      echo "This may take 3-5 minutes for nodes to join and become Ready..."
      
      # Wait until at least 2 nodes are in Ready state
      until [ $(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready") -ge 2 ]; do
        echo "  Waiting for nodes... (currently: $(kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready') Ready)"
        sleep 15
      done
      
      echo ""
      echo "✓✓✓ All worker nodes are Ready!"
      echo ""
      kubectl get nodes -o wide
    EOT
  }

  depends_on = [
    aws_eks_node_group.main
  ]
}
