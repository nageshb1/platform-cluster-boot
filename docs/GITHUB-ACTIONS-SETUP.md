# GitHub Actions Setup Guide

This guide walks you through setting up GitHub Actions for automated Terraform deployments.

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **S3 Bucket** for Terraform state storage
3. **GitHub Repository** with Actions enabled

**Note**: This setup uses native S3 locking (`use_lockfile`), so no DynamoDB table is required.

## Step 1: Create S3 Bucket for State

Create an S3 bucket to store Terraform state:

```bash
# Set variables
BUCKET_NAME="your-terraform-state-bucket"
REGION="us-west-2"

# Create bucket
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

## Step 2: Set Up AWS OIDC Provider

GitHub Actions uses OpenID Connect (OIDC) to authenticate with AWS without storing long-lived credentials.

### 2.1 Create OIDC Provider (One-time per AWS account)

```bash
# Get your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --tags Key=Name,Value=GitHubActionsOIDC
```

### 2.2 Create IAM Role for GitHub Actions

Create a trust policy file:

```bash
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
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
    }
  ]
}
EOF
```

**Important**: Replace `YOUR_GITHUB_USERNAME` with your GitHub username or organization name.

Create the IAM role:

```bash
aws iam create-role \
  --role-name GitHubActionsTerraformRole \
  --assume-role-policy-document file://trust-policy.json \
  --description "Role for GitHub Actions to run Terraform"
```

### 2.3 Attach Required Policies

Attach policies that grant permissions to create EKS, VPC, and other resources:

```bash
# Get the role ARN
ROLE_ARN=$(aws iam get-role --role-name GitHubActionsTerraformRole --query 'Role.Arn' --output text)

# Attach AWS managed policies
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

# Attach S3 policy for state management
aws iam attach-role-policy \
  --role-name GitHubActionsTerraformRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
```

**Note**: For production, create custom policies with least-privilege access instead of full access.

## Step 3: Configure GitHub Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add the following:

### Required Secrets

- **`AWS_ROLE_ARN`**: The ARN of the IAM role created in Step 2.2
  - Example: `arn:aws:iam::123456789012:role/GitHubActionsTerraformRole`

### Optional Secrets (for Remote State)

If you want to use S3 backend for state storage:

- **`TF_BACKEND_BUCKET`**: Your S3 bucket name
  - Example: `your-terraform-state-bucket`
- **`TF_BACKEND_KEY`**: State file key (optional, defaults to `platform-eks/terraform.tfstate`)
  - Example: `platform-eks/terraform.tfstate`
- **`TF_BACKEND_REGION`**: AWS region for state bucket (optional, defaults to `us-west-2`)
  - Example: `us-west-2`
- **`TF_BACKEND_USE_LOCKFILE`**: Set to `true` for native S3 locking (optional, defaults to `true`)
  - Example: `true`

## Step 4: Update Trust Policy for Your Repository

Update the trust policy to match your exact repository:

```bash
# Update trust-policy.json with your GitHub username/org and repo name
# Replace YOUR_GITHUB_USERNAME with your actual GitHub username or organization

cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
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
    }
  ]
}
EOF

# Update the role
aws iam update-assume-role-policy \
  --role-name GitHubActionsTerraformRole \
  --policy-document file://trust-policy.json
```

## Step 5: Test the Workflow

1. Push changes to your repository
2. Go to **Actions** tab in GitHub
3. You should see the workflow running
4. For pull requests, it will validate and plan
5. For pushes to main, it will validate, plan, and apply

## Workflow Behavior

### On Pull Request
- ✅ Terraform format check
- ✅ Terraform validation
- ✅ Terraform plan
- 📝 Comments on PR with plan output

### On Push to Main
- ✅ Terraform format check
- ✅ Terraform validation
- ✅ Terraform plan
- ✅ Terraform apply (auto-approve)

### Manual Trigger
- You can manually trigger the workflow from the Actions tab using `workflow_dispatch`

## Troubleshooting

### Authentication Errors

**Error**: `Not authorized to perform sts:AssumeRoleWithWebIdentity`

- Verify the OIDC provider exists: `aws iam list-open-id-connect-providers`
- Check the trust policy matches your repository path exactly
- Ensure the role ARN in GitHub secrets is correct

### Backend Configuration Errors

**Error**: `Failed to get existing workspaces`

- Verify S3 bucket exists and is accessible
- Check IAM role has S3 permissions
- Verify bucket name in secrets is correct

### State Lock Errors

**Error**: `Error acquiring the state lock`

- Check if another workflow is running
- Verify S3 bucket has proper permissions for lock file operations
- Manually release lock if needed (delete `.tflock` file from S3)

### Permission Errors

**Error**: `AccessDenied` when creating resources

- Verify IAM role has required permissions
- Check policy attachments: `aws iam list-attached-role-policies --role-name GitHubActionsTerraformRole`
- Review CloudTrail logs for specific denied actions

## Security Best Practices

1. **Least Privilege**: Create custom IAM policies with only required permissions
2. **State Encryption**: Always enable encryption on S3 bucket
3. **State Locking**: Use native S3 locking (`use_lockfile`) to prevent concurrent modifications
4. **Branch Protection**: Enable branch protection rules on main branch
5. **Required Reviews**: Require PR reviews before merging to main
6. **Secrets Rotation**: Regularly review and rotate secrets

## Custom IAM Policy Example

Instead of using full access policies, create a custom policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "eks:*",
        "iam:*",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": "*"
    }
  ]
}
```

Attach it to the role:

```bash
aws iam put-role-policy \
  --role-name GitHubActionsTerraformRole \
  --policy-name TerraformCustomPolicy \
  --policy-document file://custom-policy.json
```

## Next Steps

After setup is complete:

1. Make a test commit to trigger the workflow
2. Monitor the Actions tab for any issues
3. Review the Terraform plan output
4. Once confident, merge to main to apply changes
