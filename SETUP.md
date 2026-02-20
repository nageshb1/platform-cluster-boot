# Quick Setup Guide

Follow these steps to deploy infrastructure using GitHub Actions.

## Step 1: Create AWS Resources

### 1.1 Create S3 Bucket

Ensure you have an S3 bucket created. If needed, create it manually:

```bash
# Set variables
BUCKET_NAME="your-terraform-state-bucket"
REGION="us-west-2"

# Create S3 bucket
aws s3 mb s3://$BUCKET_NAME --region $REGION

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### 1.2 Set Up AWS OIDC Provider (One-time per AWS account)

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 1.3 Create IAM Role

See [GitHub Actions Setup Guide](docs/GITHUB-ACTIONS-SETUP.md) for detailed IAM role creation steps.

Quick version:
```bash
# Get your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create trust policy (replace YOUR_GITHUB_USERNAME)
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/platform-cluster-boot:*"
      }
    }
  }]
}
EOF

# Create role
aws iam create-role \
  --role-name GitHubActionsTerraformRole \
  --assume-role-policy-document file://trust-policy.json

# Attach policies
aws iam attach-role-policy \
  --role-name GitHubActionsTerraformRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

aws iam attach-role-policy \
  --role-name GitHubActionsTerraformRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

aws iam attach-role-policy \
  --role-name GitHubActionsTerraformRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess

aws iam attach-role-policy \
  --role-name GitHubActionsTerraformRole \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess

aws iam attach-role-policy \
  --role-name GitHubActionsTerraformRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# Get role ARN
aws iam get-role --role-name GitHubActionsTerraformRole --query 'Role.Arn' --output text
```

## Step 2: Configure GitHub Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add:

   **Required:**
   - `AWS_ROLE_ARN` - The ARN from step 1.3 (e.g., `arn:aws:iam::123456789012:role/GitHubActionsTerraformRole`)

   **Optional (for remote state):**
   - `TF_BACKEND_BUCKET` - Your S3 bucket name
   - `TF_BACKEND_KEY` - State file key (defaults to `platform-eks/terraform.tfstate`)
   - `TF_BACKEND_REGION` - AWS region (defaults to `us-west-2`)
   - `TF_BACKEND_USE_LOCKFILE` - Set to `true` for native S3 locking (optional, defaults to `true`)

## Step 3: Deploy

Push to `main` branch to trigger deployment:

```bash
git add .
git commit -m "Initial infrastructure setup"
git push origin main
```

Monitor the deployment in the **Actions** tab of your GitHub repository.

## Verification

After deployment completes:

1. Check Terraform outputs in GitHub Actions logs
2. Verify EKS cluster:
   ```bash
   aws eks describe-cluster --name platform-eks --region us-west-2
   ```
3. Configure kubectl:
   ```bash
   aws eks update-kubeconfig --name platform-eks --region us-west-2
   ```

## Troubleshooting

- **Authentication errors**: Verify OIDC provider and IAM role trust policy
- **Backend errors**: Check S3 bucket exists and IAM role has S3 permissions
- **Permission errors**: Verify IAM role has required policies attached

See [GitHub Actions Setup Guide](docs/GITHUB-ACTIONS-SETUP.md) for detailed troubleshooting.
