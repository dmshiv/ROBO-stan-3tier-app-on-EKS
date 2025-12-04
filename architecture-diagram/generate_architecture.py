from diagrams import Diagram, Cluster, Edge
from diagrams.aws.general import Users
from diagrams.aws.network import VPC, PublicSubnet, PrivateSubnet, InternetGateway, NATGateway, Route53, ALB, ELB
from diagrams.aws.compute import EKS, EC2
from diagrams.aws.security import IAMRole
from diagrams.aws.storage import EBS
from diagrams.onprem.database import MongoDB, MySQL
from diagrams.onprem.inmemory import Redis
from diagrams.k8s.network import Ingress, Service
from diagrams.k8s.compute import Pod, StatefulSet
from diagrams.k8s.group import Namespace

GRAPH_ATTR = {
    "fontsize": "22",
    "fontname": "Helvetica",
    "bgcolor": "white",
    "pad": "1.0",
    "dpi": "350",
    "splines": "ortho",
    "nodesep": "1.5",
    "ranksep": "2.5",
    "rankdir": "LR",
    "labelloc": "t",
    "compound": "true",
}

NODE_ATTR = {
    "fontsize": "13",
    "fontname": "Helvetica",
    "height": "1.5",
    "width": "1.5",
}

EDGE_ATTR = {
    "fontsize": "11",
    "fontname": "Helvetica",
    "labeldistance": "2.0",
}

with Diagram(
    "Robot Shop 3-Tier Architecture on AWS EKS - Complete Infrastructure Flow",
    filename="robot_shop_architecture",
    show=False,
    direction="LR",
    graph_attr=GRAPH_ATTR,
    node_attr=NODE_ATTR,
    edge_attr=EDGE_ATTR,
    outformat="png",
):
    
    # --- ENTRY POINT ---
    users = Users("End Users\n(Direct ALB Access)")

    # --- AWS CLOUD ---
    with Cluster("AWS Cloud Region: us-east-1"):
        
        # --- IAM ROLES (Security Layer) ---
        with Cluster("IAM Roles & Service Accounts (IRSA)", graph_attr={"bgcolor": "#fff3cd", "style": "rounded"}):
            iam_eks = IAMRole("EKS Cluster Role\nManages K8s API\nServer operations")
            iam_node = IAMRole("Node Instance Profile\nEC2 permissions for\nContainer runtime")
            iam_alb = IAMRole("ALB Controller SA\n(IRSA) Manages ELB\nresources via K8s")
            iam_ebs = IAMRole("EBS CSI Driver SA\n(IRSA) Provisions\nEBS volumes")

        # --- VPC LAYER ---
        with Cluster("VPC 10.0.0.0/16 - Network Isolation Boundary"):
            
            # --- PUBLIC TIER ---
            with Cluster("Public Subnets (2 AZs)\n10.0.1.0/24 & 10.0.2.0/24", graph_attr={"bgcolor": "#d4edda"}):
                igw = InternetGateway("Internet Gateway\nVPC entry/exit point")
                
                alb = ALB("Application Load Balancer\nLayer 7 HTTP/HTTPS\nRouting to targets")
                
                nat = NATGateway("NAT Gateway\nOutbound internet for\nprivate subnets")

            # --- PRIVATE TIER ---
            with Cluster("Private Subnets (2 AZs)\n10.0.3.0/24 & 10.0.4.0/24", graph_attr={"bgcolor": "#cfe2ff"}):
                
                # --- EKS CONTROL PLANE ---
                with Cluster("EKS Control Plane (Managed)", graph_attr={"bgcolor": "#f8d7da"}):
                    eks = EKS("EKS Cluster\nKubernetes v1.28\nOIDC Provider enabled")

                # --- WORKER NODES ---
                with Cluster("Managed Node Group", graph_attr={"bgcolor": "#e2e3e5"}):
                    node_group = EC2("EC2 Worker Nodes\nt3.medium x 2\nRunning pods")
                    
                    # --- SYSTEM ADDONS ---
                    with Cluster("Kubernetes System Components", graph_attr={"style": "dashed"}):
                        alb_controller = Pod("AWS Load Balancer\nController\nWatches Ingress\ncreates ALB")
                        ebs_csi = Pod("EBS CSI Driver\nDynamically provisions\nEBS volumes as PVs")
                        ingress_resource = Ingress("Ingress Resource\nDefines HTTP routing\nrules to services")

                    # --- APPLICATION TIER ---
                    with Cluster("Robot Shop Application (Helm Deployed)", graph_attr={"style": "dashed"}):
                        
                        # Frontend
                        web = Pod("web\nAngular Frontend\nServes UI")
                        
                        # Backend Services - Row 1
                        cart = Pod("cart\nNode.js\nManages shopping cart")
                        catalogue = Pod("catalogue\nNode.js\nProduct listings")
                        user = Pod("user\nNode.js\nUser authentication")
                        
                        # Backend Services - Row 2
                        ratings = Pod("ratings\nPHP\nProduct reviews")
                        shipping = Pod("shipping\nSpring Boot\nOrder fulfillment")
                        payment = Pod("payment\nPython\nPayment processing")
                        dispatch = Pod("dispatch\nGo\nOrder dispatch queue")

                    # --- DATA TIER ---
                    with Cluster("Stateful Data Services", graph_attr={"style": "dashed", "bgcolor": "#f5f5f5"}):
                        mongo = MongoDB("MongoDB\nStores user profiles\nand product catalog")
                        redis = Redis("Redis\nSession cache for\nshopping carts")
                        mysql = MySQL("MySQL\nStores orders and\nratings data")

                # --- STORAGE ---
                with Cluster("Persistent Storage"):
                    ebs = EBS("EBS gp3 Volumes\nDynamic PVCs\nfor databases")

    # ==================== TRAFFIC FLOW ====================
    
    # User -> Internet Gateway -> ALB
    users >> Edge(label="HTTPS Request (ALB URL)", color="#27ae60", style="bold", penwidth="2.5") >> igw
    
    # Internet Gateway -> ALB
    igw >> Edge(label="Forward to ALB", color="#27ae60", penwidth="2.0") >> alb
    
    # ALB -> Ingress -> Web Service
    alb >> Edge(label="Target: K8s Service", color="#27ae60", penwidth="2.0") >> ingress_resource
    ingress_resource >> Edge(label="Route to web pod", color="#27ae60") >> web
    
    # Web UI -> Backend Services
    web >> Edge(label="API Calls", color="#3498db", style="solid", penwidth="1.5") >> cart
    web >> Edge(color="#3498db", style="solid") >> catalogue
    web >> Edge(color="#3498db", style="solid") >> user
    web >> Edge(color="#3498db", style="solid") >> ratings
    
    # Inter-service communication
    cart >> Edge(color="#3498db") >> shipping
    shipping >> Edge(color="#3498db") >> payment
    dispatch >> Edge(color="#3498db") >> shipping
    
    # ==================== DATA PERSISTENCE ====================
    
    # Services -> Databases
    cart >> Edge(label="Session data", color="#e74c3c", style="dashed", penwidth="2.0") >> redis
    catalogue >> Edge(label="Product data", color="#e74c3c", style="dashed", penwidth="2.0") >> mongo
    user >> Edge(label="User profiles", color="#e74c3c", style="dashed", penwidth="2.0") >> mongo
    shipping >> Edge(label="Orders", color="#e74c3c", style="dashed", penwidth="2.0") >> mysql
    ratings >> Edge(label="Reviews", color="#e74c3c", style="dashed", penwidth="2.0") >> mysql
    
    # Databases -> Persistent Volumes
    mongo >> Edge(label="PVC", color="#95a5a6", style="dotted") >> ebs
    redis >> Edge(label="PVC", color="#95a5a6", style="dotted") >> ebs
    mysql >> Edge(label="PVC", color="#95a5a6", style="dotted") >> ebs
    
    # ==================== CONTROL PLANE ====================
    
    # IAM -> Components (IRSA & Instance Profiles)
    iam_eks >> Edge(label="Assumes role", color="#f39c12", style="dotted", penwidth="1.5") >> eks
    iam_node >> Edge(label="Instance profile", color="#f39c12", style="dotted", penwidth="1.5") >> node_group
    iam_alb >> Edge(label="IRSA token", color="#f39c12", style="dotted", penwidth="1.5") >> alb_controller
    iam_ebs >> Edge(label="IRSA token", color="#f39c12", style="dotted", penwidth="1.5") >> ebs_csi
    
    # Controllers -> AWS Resources
    alb_controller >> Edge(label="Creates/Updates", color="#9b59b6", style="dashed", penwidth="1.5") >> alb
    ebs_csi >> Edge(label="Provisions volumes", color="#9b59b6", style="dashed", penwidth="1.5") >> ebs
    
    # ==================== OUTBOUND TRAFFIC ====================
    
    # NAT for private subnet internet access
    node_group >> Edge(label="Image pulls\nPackage updates", color="#7f8c8d", style="dashed") >> nat
    nat >> Edge(color="#7f8c8d", style="dashed") >> igw
