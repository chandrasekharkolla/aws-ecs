include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_parent_terragrunt_dir()}//src/modules/ecs_cluster"
}

dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id          = ""
    private_subnets = [""]
    intra_subnets   = [""]
    public_subnets  = [""]
  }
}

locals {
  region = "us-east-1"
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
    provider "aws" {
      region = "${local.region}"
      default_tags {
        tags = {
          Environment = "dev"
        }
      }
    }
EOF
}

remote_state {
  backend = "s3"

  config = {
    bucket         = "test-eks-terraform-remote-state"
    dynamodb_table = "DynamoDBTerraformStateLockTable"
    encrypt        = true
    region         = local.region
    key            = "ecs.tfstate"
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

inputs = {
  # Common Configs
  region                    = local.region
  cluster_name              = "white-hart"
  cloudwatch_group_name     = "white-hart-cluster"
  task_definition_name      = "test"
  lb_target_group_name      = "test"
  vpc_id                    = dependency.vpc.outputs.vpc_id
  private_subnets           = dependency.vpc.outputs.private_subnets
  public_subnets            = dependency.vpc.outputs.public_subnets
  hosted_zone_name          = "moonlightadventures.net"
  service_name              = "test"
  task_cpu                  = 1024
  task_memory               = 2048
  cert_domain_name          = "first.moonlightadventures.net"
  cert_domain_names         = ["test.moonlightadventures.net"]
  subject_alternative_names = ["first.moonlightadventures.net", "test1.moonlightadventures.net", "test2.moonlightadventures.net", "test3.moonlightadventures.net"]
  ecs_task_tags = {
    platform = "Task-test"
  }
  taskRoleArn          = "arn:aws:iam::380274579570:role/ecsTaskExecutionRole"
  ecs_executionRoleArn = "arn:aws:iam::380274579570:role/ecsTaskExecutionRole"
  lb_name              = "test"
  image_uri            = "380274579570.dkr.ecr.us-east-1.amazonaws.com/go:latest"
}