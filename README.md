# Terraform Deployment for Tyk MDCB Installation

This repository contains Terraform configurations to deploy the **Tyk Multi-Data Center Bridge (MDCB)** setup, including both **Control Plane** and **Data Plane** Helm charts. This setup enables a distributed Tyk Gateway architecture supporting global scaling and high availability across multiple data centers.

## Prerequisites

Before starting, ensure the following tools and configurations are set up on your local machine:

- **Terraform**: [Download and install Terraform](https://www.terraform.io/downloads) for your OS.
- **Helm**: [Install Helm](https://helm.sh/docs/intro/install/) to manage Kubernetes applications.
- **Docker Desktop**: Ensure Docker Desktop is installed with the **Kubernetes** feature enabled. This configuration uses Docker Desktop’s Kubernetes cluster as the provider.
- **Tyk Dashboard and MDCB Licenses**: Obtain the required licenses for Tyk Dashboard and MDCB, you'll need to update them in the values.yaml file located in the control-plane directory.

## Getting Started

### 1. Clone the Repository
Clone this repository to your local machine:

```bash
git clone https://github.com/mhuaco/Tyk-mdcb-Terraform.git
cd terraform-tyk-mdcb
```
### 2. Initialize Terraform
Run the following command to initialize the Terraform workspace. This will download the necessary provider plugins and set up the working directory for Terraform.

```bash
terraform init
```
### 3. Update the values.yaml file located in the control-plane directory with the Tyk Dashboard and MDCB licenses.

### 4. Use the following command to deploy MDCB. This command will install both the Control Plane and Data Plane.
```bash
terraform apply
```


### 5. Verify the Deployment
After deployment is complete, you can verify the status of both the Control Plane and Data Plane by running:

```bash

kubectl get pods -n tyk-cp
kubectl get pods -n tyk-dp
```


# Bringing Down the Infrastructure
To bring down the deployed Tyk MDCB infrastructure, use the following command:

```bash
 
terraform destroy
```
Warning: terraform destroy will delete all infrastructure and associated data. Ensure that you back up any important data before proceeding.

You will be prompted to confirm this action. Type yes to proceed.
