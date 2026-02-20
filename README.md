# Platform Cluster Boot

Terraform configuration to bootstrap an EKS cluster for hosting Crossplane and ArgoCD controllers.

## Project Structure

```
.
├── infra/              # Terraform configuration for EKS cluster
│   ├── main.tf        # Main Terraform configuration
│   ├── variables.tf   # Variable definitions
│   ├── outputs.tf     # Output definitions
│   └── backend.tf     # Backend configuration (configured via GitHub Actions)
├── k8s/               # Kubernetes manifests (ArgoCD, Crossplane)
├── .github/workflows/ # GitHub Actions CI/CD pipeline
└── docs/              # Documentation

```

## Features

- **Minimal Cost**: Single t3.small spot instance (~$79/month)
- **VPC & Networking**: Automated VPC, subnets, and NAT gateway setup
- **EKS Cluster**: Managed Kubernetes cluster with IRSA enabled
- **CI/CD Ready**: GitHub Actions pipeline for automated deployments

## Prerequisites

- AWS Account with permissions to create EKS, VPC, and IAM resources
- AWS credentials configured (see [AWS Credentials Setup](docs/AWS-CREDENTIALS.md))
- GitHub repository with Actions enabled

## Quick Start

### 1. Set Up Remote State (S3 Backend)

Ensure you have an S3 bucket for Terraform state storage. Then configure backend:

```bash
# Edit infra/backend-config.hcl with your bucket name and backend settings
cd infra
terraform init -backend-config="backend-config.hcl"
```

**Note:** In PowerShell, always use quotes: `terraform init -backend-config="backend-config.hcl"`

See [Backend Setup Guide](docs/BACKEND-SETUP.md) for detailed instructions.

### 2. Configure GitHub Actions

1. **Set up AWS OIDC provider** (one-time per AWS account):
   ```bash
   aws iam create-open-id-connect-provider \
     --url https://token.actions.githubusercontent.com \
     --client-id-list sts.amazonaws.com \
     --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
   ```

2. **Create IAM role** (see [GitHub Actions Setup Guide](docs/GITHUB-ACTIONS-SETUP.md))

3. **Configure GitHub Secrets**:
   - Go to Repository → **Settings** → **Secrets and variables** → **Actions**
   - Add `AWS_ROLE_ARN` (required)
   - Add `TF_BACKEND_BUCKET` (optional, for remote state)
   - Add `TF_BACKEND_USE_LOCKFILE` (optional, set to `true` for native S3 locking - default)
   - Add `TF_BACKEND_USE_LOCKFILE` (optional, defaults to `true` for native S3 locking)

### 3. Deploy Infrastructure

Push changes to `main` branch to trigger automatic deployment:

```bash
git add .
git commit -m "Initial infrastructure setup"
git push origin main
```

The GitHub Actions workflow will:
- ✅ Validate Terraform configuration
- ✅ Plan infrastructure changes
- ✅ Apply changes automatically

## Pipeline Behavior

- **On Pull Request**: Validates Terraform, runs plan, and comments on PR
- **On Push to Main**: Validates, plans, and automatically applies changes
- **Manual Trigger**: Can be triggered manually from Actions tab

## Configuration

Default variables are defined in `infra/variables.tf`:
- `vpc_cidr` - VPC CIDR block (default: `10.0.0.0/16`)
- `availability_zones` - List of AZs (default: `["us-west-2a", "us-west-2b"]`)
- `private_subnet_cidrs` - Private subnet CIDRs
- `public_subnet_cidrs` - Public subnet CIDRs

Override variables by creating `terraform.tfvars` or using environment variables.

## Outputs

After deployment, Terraform outputs:
- `cluster_name` - EKS cluster name
- `cluster_endpoint` - EKS API endpoint
- `vpc_id` - VPC ID
- `private_subnet_ids` - Private subnet IDs
- `public_subnet_ids` - Public subnet IDs

## Next Steps

After the EKS cluster is created:

1. Configure kubectl:
   ```bash
   aws eks update-kubeconfig --name platform-eks --region us-west-2
   ```

2. Deploy ArgoCD and Crossplane (see `k8s/` directory)

## Documentation

- [AWS Credentials Setup](docs/AWS-CREDENTIALS.md) - Configure AWS credentials for Terraform
- [Backend Setup Guide](docs/BACKEND-SETUP.md) - S3 remote state configuration
- [GitHub Actions Setup Guide](docs/GITHUB-ACTIONS-SETUP.md) - Detailed CI/CD setup instructions
