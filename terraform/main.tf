terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
}

provider "kubernetes" {
    host = module.eks.cluster_endpoint
    #token = data.aws_eks_cluster_auth.cluster.token
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    
    exec {
        api_version = "client.authentication.k8s.io/v1alpha1"
        command     = "aws"
        # This requires the awscli to be installed locally where Terraform is executed
        args = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
    }
}

data "aws_availability_zones" "azs" {
    state = "available"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "edgardaon-vpc"
  cidr = "10.0.0.0/16"

  azs            = data.aws_availability_zones.azs.names
  public_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  enable_dns_hostnames = true

  map_public_ip_on_launch = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
    Name        = "edgardaon-vpc"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.0"
  cluster_name    = "edgardaon-eks-cluster"
  cluster_version = "1.21"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    disk_size      = 16
    instance_types = ["t2.small"]

    tags = {
      "kubernets.io/cluster/edgardaon-eks-cluster" = "owned"
    }
  }

  eks_managed_node_groups = {
    blue = {}
    green = {
      max_size     = 4
      min_size     = 3
      desired_size = 3

      instance_types = ["t2.small"]

      associate_public_ip_address = true
      subnet_ids                  = module.vpc.public_subnets
    }
  }

  # aws-auth configmap
  manage_aws_auth_configmap = true

  tags = {
    Environment = "dev"
    Terraform   = "true"
    Name        = "edgardaon-eks-cluster"
  }
}