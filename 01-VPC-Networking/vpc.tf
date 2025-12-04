# =============================================
# VPC NETWORKING - The Foundation of Everything
# =============================================
# WHAT THIS FILE DOES:
# Creates the entire network infrastructure - like building the roads, 
# highways, and security checkpoints before building the actual buildings (EKS, apps)
#
# WHY IT'S NEEDED:
# Every AWS resource needs a network to live in. VPC is your private 
# section of AWS cloud where only you control what goes in and out.
#
# COMPONENTS CREATED:
# 1. VPC (Virtual Private Cloud) - Your private network
# 2. Internet Gateway - Door to the internet
# 3. Public Subnets - For internet-facing stuff (Load Balancers)
# 4. Private Subnets - For internal stuff (Worker Nodes)
# 5. NAT Gateways - Let private resources access internet (but not vice versa)
# 6. Route Tables - Traffic rules (like road signs)
#
# ANALOGY:
# Think of VPC as building a gated community:
# - VPC = The entire gated community
# - Internet Gateway = Main entrance gate
# - Public Subnets = Houses near the main road (visible to outside)
# - Private Subnets = Houses deep inside (hidden from outside)
# - NAT Gateway = Security escort that lets residents go out but blocks strangers
# - Route Tables = Road signs telling traffic where to go


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 1. VPC - THE MAIN NETWORK CONTAINER                                            ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Creates the main Virtual Private Cloud (your private network in AWS)
# WHY: Everything we build needs to live inside this VPC
# DOES: Creates an isolated network with 65,536 IP addresses (10.0.0.0/16)

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  
  # Enable DNS features - required for EKS to work properly
  # Without these, pods can't resolve domain names!
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-vpc"
      # IMPORTANT: This tag tells EKS "this VPC belongs to your cluster"
      # Without this, EKS won't be able to find and use this VPC!
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 2. INTERNET GATEWAY - THE DOOR TO THE INTERNET                                 ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Creates a gateway that connects your VPC to the internet
# WHY: Without this, nothing in your VPC can reach the internet (or be reached)
# DOES: Acts as the main entrance/exit for internet traffic
# ANALOGY: The main gate of your gated community

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-igw"
    }
  )
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 3. PUBLIC SUBNETS - INTERNET-FACING AREAS                                      ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Creates subnets where resources CAN have public IP addresses
# WHY: Load Balancers need to be in public subnets to receive internet traffic
# DOES: Creates 2 public subnets in different AZs for high availability
# NOTE: "map_public_ip_on_launch" means any EC2 here gets a public IP automatically

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  
  # Auto-assign public IPs to instances launched here
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-public-subnet-${count.index + 1}"
      # CRITICAL TAG: Tells AWS Load Balancer Controller 
      # "Create internet-facing load balancers in these subnets"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "kubernetes.io/role/elb"                    = "1"
    }
  )
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 4. PRIVATE SUBNETS - INTERNAL/PROTECTED AREAS                                  ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Creates subnets where resources are hidden from the internet
# WHY: Worker nodes should be in private subnets for security
#      They don't need direct internet access - NAT Gateway handles outbound
# DOES: Creates 2 private subnets in different AZs for high availability

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-private-subnet-${count.index + 1}"
      # CRITICAL TAG: Tells AWS Load Balancer Controller
      # "Create internal load balancers in these subnets"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "kubernetes.io/role/internal-elb"           = "1"
    }
  )
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 5. ELASTIC IPs FOR NAT GATEWAYS                                                ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Allocates static public IP addresses for NAT Gateways
# WHY: NAT Gateways need a fixed public IP to route traffic
# DOES: Creates one EIP per public subnet (for each NAT Gateway)
# NOTE: depends_on ensures Internet Gateway exists first (NAT needs it)

resource "aws_eip" "nat" {
  count  = length(var.public_subnet_cidrs)
  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-nat-eip-${count.index + 1}"
    }
  )

  # Must create Internet Gateway first!
  depends_on = [aws_internet_gateway.main]
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 6. NAT GATEWAYS - OUTBOUND INTERNET FOR PRIVATE SUBNETS                        ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Creates NAT Gateways that let private resources access the internet
# WHY: Worker nodes in private subnets need to:
#      - Pull Docker images from Docker Hub/ECR
#      - Download packages
#      - Talk to AWS APIs
#      But we DON'T want internet traffic coming IN to them!
# DOES: One-way door - private resources can go OUT, but nothing can come IN
# ANALOGY: Security escort that takes residents out but blocks strangers

resource "aws_nat_gateway" "main" {
  count         = length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-nat-gateway-${count.index + 1}"
    }
  )

  # Must create Internet Gateway first!
  depends_on = [aws_internet_gateway.main]
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 7. PUBLIC ROUTE TABLE - TRAFFIC RULES FOR PUBLIC SUBNETS                       ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Creates routing rules for public subnets
# WHY: Traffic needs to know where to go - this says "internet traffic goes through IGW"
# DOES: Routes all traffic (0.0.0.0/0) to the Internet Gateway
# ANALOGY: Road signs saying "To Internet → Use Main Gate"

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Route: "Any traffic going to the internet (0.0.0.0/0) should use the Internet Gateway"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-public-rt"
    }
  )
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 8. PUBLIC ROUTE TABLE ASSOCIATIONS - CONNECT SUBNETS TO ROUTE TABLE            ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Connects public subnets to the public route table
# WHY: Subnets need to be associated with a route table to use its rules
# DOES: "These subnets should follow the public route table rules"

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 9. PRIVATE ROUTE TABLES - TRAFFIC RULES FOR PRIVATE SUBNETS                    ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Creates routing rules for private subnets
# WHY: Private subnets need to reach internet through NAT Gateway (not directly)
# DOES: Routes internet traffic (0.0.0.0/0) through NAT Gateway
# NOTE: One route table per private subnet (each uses its own NAT in same AZ)

resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  # Route: "Any traffic going to internet should use NAT Gateway"
  # This allows outbound traffic but blocks inbound!
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-private-rt-${count.index + 1}"
    }
  )
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║ 10. PRIVATE ROUTE TABLE ASSOCIATIONS - CONNECT SUBNETS TO ROUTE TABLE          ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
# WHAT: Connects private subnets to their respective private route tables
# WHY: Each private subnet uses its own route table (for AZ-specific NAT routing)
# DOES: Associates each private subnet with its matching private route table

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
