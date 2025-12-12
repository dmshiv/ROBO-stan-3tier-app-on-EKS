# Robot Shop on EKS (Terraform + Helm)

Deploy Stan's Robot Shop (microservices demo app) on AWS EKS using Terraform. The infrastructure is split into numbered folders (VPC → EKS → NodeGroup → EBS CSI → ALB Controller → Helm install).

## What you get

- An AWS VPC with public/private subnets
- An EKS cluster + EC2 worker nodes
- EBS CSI Driver (storage for stateful services)
- AWS Load Balancer Controller
- Robot Shop installed via Helm in the `robot-shop` namespace
- Public access via ALB Ingress (see `06-Robot-Shop-Helm/robot-shop-helm/ingress.yaml`)

## Repo layout (apply order)

Apply in this order (foundation → app):

1. `01-VPC-Networking`
2. `02-EKS-Cluster`
3. `03-EC2-NodeGroup`
4. `04-EBS-CSI-Driver`
5. `05-ALB-Controller`
6. `06-Robot-Shop-Helm`

Destroy in reverse order (app → foundation): `06 → 05 → 04 → 03 → 02 → 01`.

The same order is shown in `Tf-apply-destroy-order.txt`.

## Prerequisites

- AWS CLI configured (`aws sts get-caller-identity` works)
- Terraform installed
- `kubectl`
- Helm v3

## Option A: One-command pipeline (recommended)

Use the included script: `TF-apply-destroy-latest-pipeline.sh`.

```bash
cd /home/dom/K8-abhishek-veeramalla/EKS-projects/ROBO-stan-3tier-app-on-EKS
chmod +x TF-apply-destroy-latest-pipeline.sh
./TF-apply-destroy-latest-pipeline.sh
```

It will:
- Ask for AWS region
- Apply or Destroy
- Run each Terraform folder in the correct order (and reverse for destroy)

## Option B: Manual Terraform apply (step-by-step)

Run these in order:

```bash
cd /home/dom/K8-abhishek-veeramalla/EKS-projects/ROBO-stan-3tier-app-on-EKS

cd 01-VPC-Networking && terraform init && terraform apply -auto-approve && cd ..
cd 02-EKS-Cluster && terraform init && terraform apply -auto-approve && cd ..
cd 03-EC2-NodeGroup && terraform init && terraform apply -auto-approve && cd ..
cd 04-EBS-CSI-Driver && terraform init && terraform apply -auto-approve && cd ..
cd 05-ALB-Controller && terraform init && terraform apply -auto-approve && cd ..
cd 06-Robot-Shop-Helm && terraform init && terraform apply -auto-approve && cd ..
```

## Verify

```bash
kubectl get nodes
kubectl get pods -n robot-shop
kubectl get svc -n robot-shop
kubectl get ingress -n robot-shop
```

To see the ALB hostname:

```bash
kubectl get ingress -n robot-shop -o wide
```

If the pipeline writes an ALB URL file, check `alb-url.txt`.

## How ingress works (quick)

- Ingress is defined in `06-Robot-Shop-Helm/robot-shop-helm/ingress.yaml`.
- It uses `ingressClassName: alb` and ALB annotations.
- The ALB sends traffic to pods using `alb.ingress.kubernetes.io/target-type: ip`.

## Cleanup

Recommended: run the pipeline and choose **Destroy**.

Manual destroy (reverse order):

```bash
cd /home/dom/K8-abhishek-veeramalla/EKS-projects/ROBO-stan-3tier-app-on-EKS

cd 06-Robot-Shop-Helm && terraform destroy -auto-approve && cd ..
cd 05-ALB-Controller && terraform destroy -auto-approve && cd ..
cd 04-EBS-CSI-Driver && terraform destroy -auto-approve && cd ..
cd 03-EC2-NodeGroup && terraform destroy -auto-approve && cd ..
cd 02-EKS-Cluster && terraform destroy -auto-approve && cd ..
cd 01-VPC-Networking && terraform destroy -auto-approve && cd ..
```

## Troubleshooting

- **Ingress has no hostname**: wait 2–5 minutes; check controller pods in `kube-system`.
- **ALB controller issues**: confirm step `05-ALB-Controller` applied successfully.
- **Pods Pending**: check storage class / PVs; step `04-EBS-CSI-Driver` should be applied.
- **No access to UI**: verify `kubectl get ingress -n robot-shop` and open the ALB hostname in a browser.

## Extras

- Architecture image: `architecture-diagram/robot_shop_architecture.png`
- Screenshots: `output-SS/`
