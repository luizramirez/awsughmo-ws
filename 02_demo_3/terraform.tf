terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.1"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
  }
    backend "s3" {
    bucket = "tf-demo-state-hoch" # pre-create or bootstrap once with CLI
    key    = "envs/dogo-grader/terraform-modules.tfstate"
    region = "us-west-1"
  }
}

provider "aws" {
  region = var.aws_region
}