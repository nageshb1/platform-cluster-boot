variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "role_name" {
  description = "Name of the IAM role for GitHub Actions"
  type        = string
  default     = "GitHubActionsTerraformRole"
}

variable "github_repositories" {
  description = "List of GitHub repositories allowed to assume this role (format: org/repo or owner/repo)"
  type        = list(string)

  validation {
    condition     = length(var.github_repositories) > 0
    error_message = "At least one repository must be specified."
  }
}

variable "tags" {
  description = "Tags to apply to the IAM role"
  type        = map(string)
  default     = {}
}
