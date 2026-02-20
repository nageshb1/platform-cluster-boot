# Terraform Backend Setup (S3 Remote State)

This guide explains how to set up and use S3 backend for Terraform remote state.

## Why Remote State?

- **Team Collaboration**: Multiple team members can work with the same state
- **State Locking**: Native S3 locking prevents concurrent modifications
- **State History**: S3 versioning provides state history
- **Security**: Encrypted state storage
- **CI/CD**: GitHub Actions can access state for automated deployments

## Architecture

- **S3 Bucket**: Stores Terraform state files and lock files
- **Native S3 Locking**: Uses `.tflock` files for state locking (Terraform 1.9+)
- **Encryption**: State files are encrypted at rest (AES256)
- **Versioning**: S3 versioning enabled for state history

## Step 1: Create Backend Resources

Create S3 bucket:

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

## Step 2: Configure Backend

### Option A: Local Development (Using backend-config.hcl)

1. Create or edit `infra/backend-config.hcl` with your values:
   ```hcl
   bucket         = "your-terraform-state-bucket"
   key            = "platform-eks/terraform.tfstate"
   region         = "us-west-2"
   encrypt        = true
   use_lockfile   = true
   ```

2. Initialize Terraform:
   
   **Bash/Linux/Mac:**
   ```bash
   cd infra
   terraform init -backend-config=backend-config.hcl
   ```
   
   **PowerShell (Windows):**
   ```powershell
   cd infra
   terraform init -backend-config="backend-config.hcl"
   ```

### Option B: Local Development (Using CLI Flags)

**Bash/Linux/Mac:**
```bash
cd infra
terraform init \
  -backend-config="bucket=your-terraform-state-bucket" \
  -backend-config="key=platform-eks/terraform.tfstate" \
  -backend-config="region=us-west-2" \
  -backend-config="encrypt=true" \
  -backend-config="use_lockfile=true"
```

**PowerShell (Windows):**
```powershell
cd infra
terraform init `
  -backend-config="bucket=your-terraform-state-bucket" `
  -backend-config="key=platform-eks/terraform.tfstate" `
  -backend-config="region=us-west-2" `
  -backend-config="encrypt=true" `
  -backend-config="use_lockfile=true"
```

### Option C: GitHub Actions (Using Secrets)

The GitHub Actions workflow automatically uses backend configuration from secrets:

1. Go to Repository → **Settings** → **Secrets and variables** → **Actions**
2. Add secrets:
   - `TF_BACKEND_BUCKET` - Your S3 bucket name
   - `TF_BACKEND_KEY` - State file key (optional, defaults to `platform-eks/terraform.tfstate`)
   - `TF_BACKEND_REGION` - AWS region (optional, defaults to `us-west-2`)
   - `TF_BACKEND_USE_LOCKFILE` - Set to `true` for native S3 locking (optional, defaults to `true`)

The workflow will automatically configure the backend when these secrets are present.

## Step 3: Verify Backend Configuration

After initialization, verify the backend:

```bash
cd infra
terraform init -migrate-state  # If migrating from local state
terraform state list            # List resources in state
```

## Backend Configuration Details

### S3 Bucket Settings

- **Versioning**: Enabled for state history
- **Encryption**: AES256 server-side encryption
- **Public Access**: Blocked
- **Lifecycle**: Consider adding lifecycle rules for old state versions

### Native S3 Locking (use_lockfile)

- **Lock File**: Creates `.tflock` file in same S3 location as state file
- **Automatic**: Terraform automatically manages lock files
- **No Additional Resources**: No additional AWS resources needed
- **Requires**: Terraform 1.9.0 or later

### State File Location

- **Key**: `platform-eks/terraform.tfstate`
- **Format**: JSON
- **Encryption**: Enabled

## State Locking

Native S3 locking (`use_lockfile`) provides state locking:

- **Automatic**: Terraform automatically acquires/releases locks via `.tflock` files
- **Lock File**: Created in same S3 location as state file with `.tflock` extension
- **Manual Release**: If needed, delete the `.tflock` file from S3

To manually release a lock:

```bash
# Delete the lock file from S3
aws s3 rm s3://your-terraform-state-bucket/platform-eks/terraform.tfstate.tflock
```

## State Migration

### From Local to Remote

If you have existing local state:

```bash
cd infra
terraform init -migrate-state
# Confirm migration when prompted
```

### From Remote to Local

```bash
cd infra
terraform init -backend=false
terraform state pull > terraform.tfstate
```

## Best Practices

1. **Never Commit State Files**: State files are in `.gitignore`
2. **Use Different Keys for Environments**: Use different `key` values for dev/staging/prod
3. **Enable Versioning**: Always enable S3 versioning for state history
4. **Monitor Costs**: Native S3 locking has no additional cost
5. **Backup Strategy**: S3 versioning provides automatic backups
6. **Access Control**: Use IAM policies to restrict access to state bucket

## Troubleshooting

### Error: "Failed to get existing workspaces"

- Verify S3 bucket exists and is accessible
- Check IAM permissions for S3 access
- Verify bucket name in backend configuration

### Error: "Error acquiring the state lock"

- Another Terraform operation is running
- Lock file may be stuck (check S3 for `.tflock` file)
- Manually release lock if needed (delete `.tflock` file)

### Error: "Access Denied" when accessing S3

- Verify IAM role/user has `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket` permissions
- Check bucket policy if using bucket policies
- Verify AWS credentials are configured correctly

### State File Not Found

- Verify the `key` path is correct
- Check if state file exists: `aws s3 ls s3://your-bucket/platform-eks/`
- May need to initialize with `terraform init`

## Security Considerations

1. **Encryption**: State files contain sensitive data (passwords, keys, etc.)
2. **Access Control**: Limit IAM permissions to only necessary actions
3. **Bucket Policy**: Consider adding bucket policy for additional security
4. **Versioning**: Keep versioning enabled for audit trail
5. **MFA Delete**: Consider enabling MFA delete for additional protection

## Cost Estimation

- **S3 Storage**: ~$0.023 per GB/month (state files are small, ~few KB)
- **S3 Requests**: ~$0.005 per 1,000 requests (includes lock file operations)
- **Estimated Monthly Cost**: < $0.50 for typical usage

## Next Steps

After backend is configured:

1. Initialize Terraform: `terraform init`
2. Verify state: `terraform state list`
3. Plan changes: `terraform plan`
4. Apply changes: `terraform apply`

For CI/CD, ensure GitHub Actions secrets are configured (see [GitHub Actions Setup Guide](GITHUB-ACTIONS-SETUP.md)).
