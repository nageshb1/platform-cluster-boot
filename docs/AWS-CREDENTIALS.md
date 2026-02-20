# AWS Credentials Setup

This guide explains how to configure AWS credentials for Terraform.

## Error: "No valid credential sources found"

This error occurs when Terraform cannot find AWS credentials. Configure credentials using one of the methods below.

## Method 1: AWS CLI Configuration (Recommended)

Configure AWS credentials using the AWS CLI:

```bash
aws configure
```

You'll be prompted for:
- **AWS Access Key ID**: Your AWS access key
- **AWS Secret Access Key**: Your AWS secret key
- **Default region**: e.g., `us-east-2`
- **Default output format**: `json` (recommended)

This creates credentials in `~/.aws/credentials` and config in `~/.aws/config`.

**Verify configuration:**
```bash
aws sts get-caller-identity
```

## Method 2: Environment Variables

Set AWS credentials as environment variables:

**Bash/Linux/Mac:**
```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="us-east-2"
```

**PowerShell (Windows):**
```powershell
$env:AWS_ACCESS_KEY_ID="your-access-key-id"
$env:AWS_SECRET_ACCESS_KEY="your-secret-access-key"
$env:AWS_DEFAULT_REGION="us-east-2"
```

**Windows CMD:**
```cmd
set AWS_ACCESS_KEY_ID=your-access-key-id
set AWS_SECRET_ACCESS_KEY=your-secret-access-key
set AWS_DEFAULT_REGION=us-east-2
```

## Method 3: Credentials File (Manual)

Create credentials file manually:

**Linux/Mac:**
```bash
mkdir -p ~/.aws
cat > ~/.aws/credentials <<EOF
[default]
aws_access_key_id = your-access-key-id
aws_secret_access_key = your-secret-access-key
EOF

cat > ~/.aws/config <<EOF
[default]
region = us-east-2
output = json
EOF
```

**Windows:**
Create files:
- `C:\Users\YourUsername\.aws\credentials`
- `C:\Users\YourUsername\.aws\config`

With content:
```
[default]
aws_access_key_id = your-access-key-id
aws_secret_access_key = your-secret-access-key
```

And:
```
[default]
region = us-east-2
output = json
```

## Method 4: IAM Role (EC2/ECS/Lambda)

If running on AWS infrastructure (EC2, ECS, Lambda), use IAM roles instead of access keys:

- **EC2**: Attach IAM role to EC2 instance
- **ECS**: Use task execution role
- **Lambda**: Use execution role

Terraform will automatically use the instance/task role credentials.

## Verify Credentials

After configuring credentials, verify they work:

```bash
aws sts get-caller-identity
```

You should see output like:
```json
{
    "UserId": "AIDAI...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

## Required IAM Permissions

Your AWS credentials need permissions for:

- **S3**: `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket`
- **EKS**: `eks:*`
- **EC2**: `ec2:*`
- **VPC**: `ec2:*` (VPC operations)
- **IAM**: `iam:*` (for EKS service roles)

### Example IAM Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-terraform-state-bucket",
        "arn:aws:s3:::your-terraform-state-bucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "eks:*",
        "ec2:*",
        "iam:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## Troubleshooting

### Error: "No valid credential sources found"

**Solutions:**
1. Run `aws configure` to set up credentials
2. Verify credentials: `aws sts get-caller-identity`
3. Check environment variables are set correctly
4. Verify credentials file exists and has correct permissions (Linux/Mac: `chmod 600 ~/.aws/credentials`)

### Error: "Access Denied"

**Solutions:**
1. Verify IAM user/role has required permissions
2. Check if MFA is required (if so, use `aws sts get-session-token`)
3. Verify region matches your resources
4. Check S3 bucket policy if using bucket policies

### Error: "Unable to locate credentials"

**Solutions:**
1. Ensure credentials file exists: `~/.aws/credentials` (Linux/Mac) or `C:\Users\YourUsername\.aws\credentials` (Windows)
2. Verify file format is correct (INI format)
3. Check for typos in access key ID or secret key
4. Ensure no extra spaces or quotes around values

## Security Best Practices

1. **Never commit credentials**: Keep `.aws/credentials` in `.gitignore`
2. **Use IAM roles**: Prefer IAM roles over access keys when possible
3. **Rotate keys**: Regularly rotate access keys
4. **Least privilege**: Grant only necessary permissions
5. **MFA**: Enable MFA for production accounts
6. **Separate accounts**: Use different AWS accounts for dev/staging/prod

## Next Steps

After configuring credentials:

1. Verify: `aws sts get-caller-identity`
2. Initialize Terraform: `terraform init -backend-config="backend-config.hcl"`
3. Plan: `terraform plan`
4. Apply: `terraform apply`
