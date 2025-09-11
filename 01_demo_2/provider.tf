terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      #version = "~> 5.1"
    }
  }
  backend "s3" {
    bucket = "tf-demo-state-hoch" # pre-create or bootstrap once with CLI
    key    = "envs/dev/terraform-modules.tfstate"
    region = "us-west-1"
  }

}

provider "aws" {
  region = var.aws_region
   default_tags {
    tags = {
      Stack = "AWSUGHMO"
    }
  }
}

locals {
  common_tags = merge(
    {
      Project     = "Terraform101"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.additional_tags
  )
}
