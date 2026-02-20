# Bootstrap: GitHub Actions IAM Role

This Terraform configuration creates the **GitHub OIDC provider** and **IAM role** that GitHub Actions uses to run Terraform **without storing any AWS credentials** in GitHub.

## When to run

- **Once per AWS account** (OIDC provider is account-wide).
- **Once per role** (or when you change `github_repositories` or policies).

Run this with credentials that can create IAM resources (e.g. local `aws configure`, or another CI that already has AWS access). After that, the main Terraform in `../` can be run by GitHub Actions using the created role.

## Prerequisites

- AWS CLI (or other auth) configured with permissions to create IAM roles and OIDC providers.
- Terraform >= 1.3.

## Usage

1. **Set your repository** (required):

   Create `terraform.tfvars` in this directory:

   ```hcl
   github_repositories = ["your-org/your-repo"]
   ```

   Or pass on the command line:

   ```bash
   terraform apply -var='github_repositories=["your-org/your-repo"]'
   ```

2. **Apply:**

   ```bash
   cd infra/bootstrap
   terraform init
   terraform plan
   terraform apply
   ```

3. **Configure GitHub:**

   - Copy the output `role_arn`.
   - In your GitHub repo: **Settings** → **Secrets and variables** → **Actions**.
   - Add secret **`AWS_ROLE_ARN`** = `role_arn` value.

After that, the main workflow (in `.github/workflows/terraform.yml`) will use OIDC and `role-to-assume` only; no access keys needed.

## Outputs

| Output           | Description |
|------------------|-------------|
| `role_arn`       | Use this as GitHub secret **AWS_ROLE_ARN** |
| `role_name`      | IAM role name |
| `oidc_provider_arn` | GitHub OIDC provider ARN |

## Multiple repositories

To allow more than one repo to assume the role:

```hcl
github_repositories = [
  "org/repo1",
  "org/repo2"
]
```

## State

Bootstrap has its own Terraform state. You can:

- Use a **local backend** (default) and keep state on your machine, or  
- Use a **remote backend** (e.g. S3) by adding a `backend` block and running `terraform init` accordingly.
