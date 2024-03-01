data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.1"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs                  = local.azs
  private_subnets      = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets       = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]
  intra_subnets        = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 52)]
  private_subnet_names = ["Private Subnet One", "Private Subnet Two", "Private Subnet Three"]
  public_subnet_names  = ["Public Subnet One", "Public Subnet Two", "Public Subnet Three"]
  intra_subnet_names   = ["Intra Subnet One", "Intra Subnet Two", "Intra Subnet Three"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  enable_ipv6            = true
  create_egress_only_igw = true

  public_subnet_ipv6_prefixes                    = [0, 1, 2]
  public_subnet_assign_ipv6_address_on_creation  = true
  private_subnet_ipv6_prefixes                   = [3, 4, 5]
  private_subnet_assign_ipv6_address_on_creation = true
  intra_subnet_ipv6_prefixes                     = [6, 7, 8]
  intra_subnet_assign_ipv6_address_on_creation   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  # tags = var.tags
}
