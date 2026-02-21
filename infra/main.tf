terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.34"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}


# VPC Module - Creates VPC, subnets, NAT gateways, and required networking components
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "platform-eks-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  # Enable NAT Gateway for private subnets (required for EKS nodes to pull images)
  enable_nat_gateway   = true
  single_nat_gateway   = true  # Use single NAT to minimize costs
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags required for EKS subnet discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    Environment = "platform"
    Terraform   = "true"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "platform-eks"
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Enable IRSA (IAM Roles for Service Accounts) - required for many EKS features
  enable_irsa = true

  # Cluster endpoint configuration
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Minimal cost configuration for control plane workloads (Crossplane, ArgoCD)
  # Single small node with spot instances for maximum cost savings
  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 1
      desired_size = 1

      instance_types = ["t3.small"]
      
      # Use spot instances for ~70% cost savings
      capacity_type = "SPOT"
      
      # Enable cluster autoscaler tags (optional, for future use)
      labels = {
        workload-type = "control-plane"
      }
    }
  }

  tags = {
    Environment = "platform"
  }
}
