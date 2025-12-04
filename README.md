# 🤖 Robot Shop 3-Tier App on AWS EKS

A complete Infrastructure-as-Code project to deploy the **Stan's Robot Shop** microservices application on **AWS EKS** using Terraform, with a custom **Bash Pipeline** for automated deployment.

---

## 🎯 What is This Project About?

This project demonstrates how to deploy a **production-ready 3-tier microservices application** on AWS using modern DevOps practices. Instead of clicking through the AWS console, everything is automated with Terraform and orchestrated by a custom Bash pipeline.

### The Problem We Solved

Deploying a multi-tier application on Kubernetes involves:
- Creating networking (VPC, subnets, NAT gateways)
- Setting up an EKS cluster with proper IAM roles
- Configuring worker nodes
- Installing storage drivers (EBS CSI)
- Setting up load balancer controllers
- Finally deploying the application

**Doing this manually is error-prone and time-consuming.** One wrong step and you spend hours debugging.

### Our Approach

We broke down the entire infrastructure into **6 modular Terraform folders**, each handling one responsibility:

| Step | Folder | What It Does |
|------|--------|--------------|
| 1 | `01-VPC-Networking` | Creates VPC, public/private subnets, NAT gateway, route tables |
| 2 | `02-EKS-Cluster` | Provisions EKS control plane with IAM roles and security groups |
| 3 | `03-EC2-NodeGroup` | Adds EC2 worker nodes to the cluster |
| 4 | `04-EBS-CSI-Driver` | Installs EBS CSI driver for persistent storage (databases need this) |
| 5 | `05-ALB-Controller` | Deploys AWS Load Balancer Controller for ingress routing |
| 6 | `06-Robot-Shop-Helm` | Deploys the Robot Shop app via Helm chart |

### Why This Order Matters

You can't deploy an app without a cluster. You can't create a cluster without a VPC. Dependencies matter!

- **Apply order:** 01 → 02 → 03 → 04 → 05 → 06 (build from foundation up)
- **Destroy order:** 06 → 05 → 04 → 03 → 02 → 01 (tear down from top)

### The Bash Pipeline Innovation

Instead of using Jenkins or GitHub Actions (which require setup, servers, YAML configs), we built a **pure Bash pipeline** that:

1. Auto-detects all Terraform folders by their numeric prefix
2. Runs `terraform init → plan → apply` in the correct order
3. Shows a **real-time visual progress bar** as each stage completes
4. Displays **execution timing** for each phase
5. Handles **errors gracefully** with retry logic
6. Reverses the order automatically for destroy operations

**One script. One command. Full automation.**

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         AWS Cloud                                   │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                        VPC                                    │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐   │  │
│  │  │ Public      │  │ Private     │  │ EKS Cluster         │   │  │
│  │  │ Subnets     │  │ Subnets     │  │  ┌───────────────┐  │   │  │
│  │  │  ┌───────┐  │  │             │  │  │ Robot Shop    │  │   │  │
│  │  │  │  ALB  │──┼──┼─────────────┼──┼─►│ Microservices │  │   │  │
│  │  │  └───────┘  │  │             │  │  └───────────────┘  │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────────────┘   │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📂 Project Structure

```
ROBO-stan-3tier-app-on-EKS/
├── 01-VPC-Networking/       # VPC, Subnets, NAT Gateway, Route Tables
├── 02-EKS-Cluster/          # EKS Cluster, IAM Roles, Security Groups
├── 03-EC2-NodeGroup/        # EC2 Worker Nodes for EKS
├── 04-EBS-CSI-Driver/       # EBS CSI Driver for persistent storage
├── 05-ALB-Controller/       # AWS Load Balancer Controller
├── 06-Robot-Shop-Helm/      # Robot Shop Helm Chart deployment
├── terraform-states/        # Local Terraform state files
├── output-SS/               # Screenshots of the deployment
├── TF-apply-destroy-latest-pipeline.sh  # 🚀 Main automation script
└── README.md
```

---

## 🚀 Bash Pipeline - The Star of This Project

Instead of Jenkins or GitHub Actions, this project uses a **custom Bash pipeline** with real-time visualization!

### Features

| Feature | Description |
|---------|-------------|
| 🔍 Auto-detects folders | Finds all Terraform folders (01-VPC, 02-EKS, etc.) automatically |
| 📊 Correct ordering | Apply: 01→02→03... / Destroy: ...03→02→01 (reverse) |
| 🌊 Visual pipeline | Shows progress bar filling left-to-right as stages complete |
| ⏱️ Timing info | Shows `[init:12s, plan:5s, apply:45s]` for each folder |
| 🔴 Error display | If something fails, shows the actual error immediately |
| 🧹 ALB cleanup | Before destroying ALB folder, deletes AWS load balancers first |
| 🔄 Auto-retry | If terraform init fails, tries 3 different methods |
| 🔒 No prompts | Never asks for input - runs fully automated |

### Pipeline Visualization

```
╔═══════════════════════════════════════════════════════════════╗
║  TERRAFORM PIPELINE  │  Region: us-east-1  │  Action: apply   ║
╚═══════════════════════════════════════════════════════════════╝

✓ 01-VPC-Networking    [init:12s, plan:5s, apply:45s]
✓ 02-EKS-Cluster       [init:10s, plan:3s, apply:520s]
► 03-EC2-NodeGroup     [init:8s, plan...]
· 04-EBS-CSI-Driver
· 05-ALB-Controller
· 06-Robot-Shop-Helm

║████████████████████░░░░░░░░░░░░░░░░░░░░░░░░║  Progress: 2/6
```

---

## 🛠️ Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- kubectl
- Helm 3
- Bash 4+

---

## 📖 Usage

### 1. Clone the repository
```bash
git clone https://github.com/dmshiv/ROBO-stan-3tier-app-on-EKS.git
cd ROBO-stan-3tier-app-on-EKS
```

### 2. Run the pipeline script
```bash
chmod +x TF-apply-destroy-latest-pipeline.sh
./TF-apply-destroy-latest-pipeline.sh
```

### 3. Follow the prompts
- Select AWS region
- Choose action: **Apply** (build) or **Destroy** (teardown)
- Select folders: all or specific numbers like `1 3 5`
- Confirm and watch the pipeline!

---

## 🌐 Accessing the Application

After deployment, get the ALB URL:
```bash
kubectl get ingress -n robot-shop
```

Or check the `alb-url.txt` file generated by the script.

---

## 🧹 Cleanup

To destroy all resources:
```bash
./TF-apply-destroy-latest-pipeline.sh
# Select "Destroy" and choose all folders
```

The script will:
1. Reverse the order (06→05→04→03→02→01)
2. Clean up ALBs and Target Groups before destroying the ALB Controller
3. Destroy each module in the correct dependency order

---

## 📸 Screenshots

| Pipeline Running | Robot Shop UI |
|------------------|---------------|
| ![Pipeline](output-SS/Screenshot%202025-12-03%20191807.png) | ![Robot Shop](output-SS/Screenshot%202025-12-03%20210541.png) |

---

## 🔧 Technologies Used

- **Cloud:** AWS (VPC, EKS, EC2, ALB, EBS, IAM)
- **IaC:** Terraform
- **Container Orchestration:** Kubernetes (EKS)
- **Package Manager:** Helm
- **Automation:** Bash scripting with ANSI visualization
- **Application:** Stan's Robot Shop (microservices demo)

---

## 👤 Author

**M Shiva Kumar**
- GitHub: [github.com/dmshiv](https://github.com/dmshiv)
- LinkedIn: [linkedin.com/in/shiva-kumar-038375207](https://www.linkedin.com/in/shiva-kumar-038375207/)

---

## 📄 License

This project is open source and available under the MIT License.

---

## ⭐ If you found this useful, give it a star!

```
Ever heard of a Bash Pipeline? 🚀
Not Jenkins. Not GitHub Actions. Just pure Bash.
```
