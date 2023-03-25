locals {
  create = var.vpc_create && var.vpc_name != ""
}

# vpc module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  count = local.create ? 1 : 0
  name  = var.vpc_name
  cidr  = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  tags = merge({
    Terraform   = "true"
    Environment = var.environment
  }, var.tags)
}