# =============================================
# ROBOT SHOP APPLICATION DEPLOYMENT
# =============================================
# WHAT THIS FILE DOES:
# Deploys the entire Robot Shop microservice application using Helm!
# Robot Shop is a sample e-commerce app with 12 microservices.
#
# WHY IT'S NEEDED:
# This is the actual application we've been building infrastructure for!
# All previous steps (VPC, EKS, Nodes, EBS, ALB) were preparation for this.
#
# COMPONENTS DEPLOYED:
# 1. Namespace for Robot Shop
# 2. Helm release from official chart
# 3. Ingress resource for external access
# 4. Wait for ALB to be created and get URL
#
# ROBOT SHOP MICROSERVICES:
# - web: Frontend (Nginx + AngularJS)
# - cart: Shopping cart (Node.js)
# - catalogue: Product catalog (Node.js)
# - user: User accounts (Node.js)
# - shipping: Shipping service (Java Spring Boot)
# - payment: Payment processing (Python Flask)
# - ratings: Product ratings (PHP)
# - dispatch: Order dispatch (Golang)
# - mongodb: Document database
# - mysql: Relational database
# - redis: Cache
# - rabbitmq: Message queue


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 1. CREATE NAMESPACE FOR ROBOT SHOP                                             ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Creates a dedicated Kubernetes namespace for Robot Shop
# WHY: Namespaces isolate applications - keeps Robot Shop separate from system pods
# DOES: Creates "robot-shop" namespace where all app pods will run

resource "kubernetes_namespace" "robot_shop" {
  metadata {
    name = var.robot_shop_namespace
    
    labels = {
      name        = var.robot_shop_namespace
      environment = "development"
      app         = "robot-shop"
    }
  }
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 2. DEPLOY ROBOT SHOP USING HELM                                                ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Installs all Robot Shop microservices using the local Helm chart
# WHY: Helm packages all 12 microservices into one easy deployment
# DOES: Creates deployments, services, and configmaps for the entire app
# NOTE: Using local chart from cloned three-tier-architecture-demo repo

resource "helm_release" "robot_shop" {
  name       = "robot-shop"
  # Using local Helm chart copied into this folder
  chart      = "${path.module}/robot-shop-helm"
  namespace  = kubernetes_namespace.robot_shop.metadata[0].name
  
  # Wait for deployment
  timeout = 900  # 15 minutes
  wait    = true
  wait_for_jobs = true

  # Configuration values
  # Use gp3 storage class for databases (EBS CSI driver provides this)
  set {
    name  = "redis.storageClassName"
    value = "gp3"
  }

  # Image pull policy
  set {
    name  = "image.pullPolicy"
    value = "IfNotPresent"
  }

  # Web replicas for high availability across AZs
  set {
    name  = "web.replicas"
    value = "2"
  }

  depends_on = [
    kubernetes_namespace.robot_shop
  ]
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 3. CREATE INGRESS FOR EXTERNAL ACCESS                                          ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Creates an Ingress resource that the ALB Controller will see
# WHY: The Ingress tells the controller to create an AWS Application Load Balancer
# DOES: Creates a public-facing ALB with a URL you can access!
#
# FLOW:
# 1. We create this Ingress resource
# 2. ALB Controller sees it
# 3. Controller creates an AWS ALB in public subnets
# 4. ALB gets a public DNS name (the URL we'll use!)
# 5. Traffic: User → ALB → web service → other microservices

resource "kubernetes_ingress_v1" "robot_shop" {
  metadata {
    name      = "robot-shop-ingress"
    namespace = kubernetes_namespace.robot_shop.metadata[0].name
    
    # These annotations tell the ALB Controller HOW to create the ALB
    annotations = {
      # Use ALB (not NLB)
      "kubernetes.io/ingress.class" = "alb"
      
      # Internet-facing (not internal)
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"
      
      # Use IP target type (sends traffic directly to pod IPs)
      "alb.ingress.kubernetes.io/target-type" = "ip"
      
      # Put ALB in public subnets
      "alb.ingress.kubernetes.io/subnets" = join(",", local.public_subnet_ids)
      
      # Health check settings
      "alb.ingress.kubernetes.io/healthcheck-path" = "/"
      "alb.ingress.kubernetes.io/healthcheck-interval-seconds" = "10"
      "alb.ingress.kubernetes.io/healthy-threshold-count" = "2"
      "alb.ingress.kubernetes.io/unhealthy-threshold-count" = "2"
      
      # ALB settings
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "idle_timeout.timeout_seconds=120"
      
      # Listen on port 80
      "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}]"
      
      # Tags for the ALB
      "alb.ingress.kubernetes.io/tags" = "Environment=development,Application=robot-shop"
    }
  }

  spec {
    # Use ingressClassName for ALB
    ingress_class_name = "alb"
    
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "web"
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.robot_shop
  ]
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 4. WAIT FOR ALL PODS TO BE READY                                               ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Waits until all Robot Shop pods are Running and Ready
# WHY: The app isn't usable until all microservices are up
# DOES: Polls until all pods show "Ready" status (no time limit!)

resource "null_resource" "wait_for_pods" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "Configuring kubectl for EKS cluster..."
      aws eks update-kubeconfig --region ${local.aws_region} --name ${local.cluster_name}
      
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "  Waiting for Robot Shop pods to be Ready (no time limit)"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
      
      # Wait for at least 10 pods (core services) to be ready
      echo "Waiting for pods..."
      until [ $(kubectl get pods -n ${var.robot_shop_namespace} --no-headers 2>/dev/null | grep -c "Running") -ge 10 ]; do
        READY=$(kubectl get pods -n ${var.robot_shop_namespace} --no-headers 2>/dev/null | grep -c "Running" || echo "0")
        TOTAL=$(kubectl get pods -n ${var.robot_shop_namespace} --no-headers 2>/dev/null | wc -l || echo "0")
        echo "  Pods Ready: $READY / $TOTAL"
        sleep 15
      done
      
      echo ""
      echo "✓ All core pods are Running!"
      echo ""
      kubectl get pods -n ${var.robot_shop_namespace} -o wide
    EOT
  }

  depends_on = [
    helm_release.robot_shop
  ]
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 5. WAIT FOR ALB AND GET URL                                                    ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Waits for the ALB to be created and retrieves its public URL
# WHY: This is the URL you'll use to access the Robot Shop application!
# DOES: Polls until ALB has a hostname, then displays it prominently

resource "null_resource" "get_alb_url" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "  Waiting for ALB to be created (no time limit)"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
      
      aws eks update-kubeconfig --region ${local.aws_region} --name ${local.cluster_name}
      
      # Wait for Ingress to get an address
      echo "Waiting for Ingress to get a load balancer address..."
      until kubectl get ingress robot-shop-ingress -n ${var.robot_shop_namespace} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null | grep -q "amazonaws.com"; do
        echo "  Waiting for ALB to be provisioned..."
        sleep 15
      done
      
      ALB_URL=$(kubectl get ingress robot-shop-ingress -n ${var.robot_shop_namespace} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
      
      echo ""
      echo ""
      echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
      echo "║                                                                               ║"
      echo "║   ✓✓✓ ROBOT SHOP IS READY! ✓✓✓                                               ║"
      echo "║                                                                               ║"
      echo "╠═══════════════════════════════════════════════════════════════════════════════╣"
      echo "║                                                                               ║"
      echo "║   Access your application at:                                                 ║"
      echo "║                                                                               ║"
      echo "║   🌐 http://$ALB_URL"
      echo "║                                                                               ║"
      echo "╠═══════════════════════════════════════════════════════════════════════════════╣"
      echo "║                                                                               ║"
      echo "║   NOTE: It may take 2-3 minutes for ALB to be fully active.                  ║"
      echo "║   If you get a 503 error, wait a moment and refresh.                         ║"
      echo "║                                                                               ║"
      echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
      echo ""
      
      # Save URL to file for easy reference
      echo "$ALB_URL" > ../alb-url.txt
      echo "URL saved to ../alb-url.txt"
    EOT
  }

  depends_on = [
    kubernetes_ingress_v1.robot_shop,
    null_resource.wait_for_pods
  ]
}
