# =============================================
# AWS LOAD BALANCER CONTROLLER - The Doorman
# =============================================
# WHAT THIS FILE DOES:
# Installs the AWS Load Balancer Controller - a special pod that watches for 
# Ingress resources and automatically creates AWS Application Load Balancers!
#
# WHY IT'S NEEDED:
# In AWS, Kubernetes Ingress doesn't automatically create load balancers.
# This controller bridges the gap:
#   - You create an Ingress resource (YAML)
#   - Controller sees it and creates a real AWS ALB
#   - ALB gets a public URL that users can access!
#
# COMPONENTS CREATED:
# 1. IAM Policy with ALB permissions
# 2. IAM Role for Controller (IRSA)
# 3. Helm release to install the controller
# 4. Verification that controller is running
#
# ANALOGY:
# Think of the ALB Controller as a smart doorman:
# - You say "I need a door to my restaurant" (Ingress)
# - The doorman automatically installs a proper entrance (ALB)
# - Customers can now enter through that door (public URL)


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 1. IAM POLICY - PERMISSIONS FOR ALB CONTROLLER                                 ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: A big permission sheet (280+ lines!) listing what the controller can do
# WHY: Controller needs to create/modify/delete load balancers, target groups, etc.
# DOES: Grants all necessary AWS permissions for ALB management

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${local.cluster_name}-aws-load-balancer-controller"
  description = "IAM policy for AWS Load Balancer Controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Permission to create service-linked role for ELB
      {
        Effect = "Allow"
        Action = ["iam:CreateServiceLinkedRole"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      # Describe permissions - read-only access to check resources
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
      },
      # Cognito, ACM, WAF, Shield permissions
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ]
        Resource = "*"
      },
      # Security group management
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["ec2:CreateSecurityGroup"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["ec2:CreateTags"]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          StringEquals = { "ec2:CreateAction" = "CreateSecurityGroup" }
          Null = { "aws:RequestTag/elbv2.k8s.aws/cluster" = "false" }
        }
      },
      {
        Effect = "Allow"
        Action = ["ec2:CreateTags", "ec2:DeleteTags"]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DeleteSecurityGroup"
        ]
        Resource = "*"
        Condition = {
          Null = { "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false" }
        }
      },
      # Load balancer and target group creation
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup"
        ]
        Resource = "*"
        Condition = {
          Null = { "aws:RequestTag/elbv2.k8s.aws/cluster" = "false" }
        }
      },
      # Listener and rule management
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule"
        ]
        Resource = "*"
      },
      # Tagging
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
        ]
      },
      # Modify resources
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DeleteTargetGroup"
        ]
        Resource = "*"
        Condition = {
          Null = { "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false" }
        }
      },
      # Add tags on creation
      {
        Effect = "Allow"
        Action = ["elasticloadbalancing:AddTags"]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          StringEquals = {
            "elasticloadbalancing:CreateAction" = ["CreateTargetGroup", "CreateLoadBalancer"]
          }
          Null = { "aws:RequestTag/elbv2.k8s.aws/cluster" = "false" }
        }
      },
      # Target registration
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      },
      # Listener modifications
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddListenerCertificates",
          "elasticloadbalancing:RemoveListenerCertificates",
          "elasticloadbalancing:ModifyRule"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 2. IAM ROLE FOR ALB CONTROLLER (IRSA)                                          ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Creates an IAM role that the ALB Controller pods can assume
# WHY: Using IRSA means no hardcoded AWS credentials in the cluster!
# DOES: Only the aws-load-balancer-controller service account can use this role

data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [local.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name               = "${local.cluster_name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
  role       = aws_iam_role.aws_load_balancer_controller.name
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 3. HELM RELEASE - INSTALL THE ALB CONTROLLER                                   ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Uses Helm to install the AWS Load Balancer Controller
# WHY: Helm makes it easy to install complex applications with all dependencies
# DOES: Deploys controller pods with proper configuration

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.6.2"
  
  # Wait settings - give it time to deploy
  timeout = 900  # 15 minutes
  wait    = true
  wait_for_jobs = true

  # Cluster name - controller needs to know which cluster it manages
  set {
    name  = "clusterName"
    value = local.cluster_name
  }

  # Create service account
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  # IRSA annotation - link service account to IAM role
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_load_balancer_controller.arn
  }

  # Region and VPC configuration
  set {
    name  = "region"
    value = local.aws_region
  }

  set {
    name  = "vpcId"
    value = local.vpc_id
  }

  depends_on = [
    aws_iam_role_policy_attachment.aws_load_balancer_controller
  ]
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 4. WAIT FOR ALB CONTROLLER TO BE READY                                         ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Verifies that the ALB Controller is fully operational
# WHY: We can't create Ingress resources until the controller is watching for them!
# DOES: Waits until controller pods are Running and Ready (no time limit)

resource "null_resource" "wait_for_alb_controller" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "Configuring kubectl for EKS cluster..."
      aws eks update-kubeconfig --region ${local.aws_region} --name ${local.cluster_name}
      
      echo "Waiting for ALB Controller pods to be fully Ready (no time limit)..."
      
      # Wait for at least 2 ALB controller pods to be Ready
      until [ $(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -o "True" | wc -l) -ge 2 ]; do
        echo "  Waiting for ALB Controller pods..."
        sleep 10
      done
      
      echo ""
      echo "✓✓✓ ALB Controller is fully operational!"
      kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
    EOT
  }

  depends_on = [
    helm_release.aws_load_balancer_controller
  ]
}
