terraform {
  backend "s3" {
    # Backend configuration is provided via:
    # 1. GitHub Actions secrets (TF_BACKEND_BUCKET, etc.) - for CI/CD
    # 2. backend-config.hcl file (for local development)
    # 3. Command-line flags: terraform init -backend-config="bucket=your-bucket" ...
    
    # Default values (can be overridden via backend-config or CLI flags)
    key          = "platform-eks/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    bucket       = "nageshb1-terraform-state-bucket"
    # bucket must be provided via backend-config or CLI flags
  }
}
