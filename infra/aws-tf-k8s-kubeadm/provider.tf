terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.11"
    }
  }
}

provider "aws" {
  region = local.region
}
