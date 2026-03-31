# # ################# SETUP #################
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.33"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~>4.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "~>2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.7"
    }
  }
}

provider "aws" {
  region  = "eu-central-1"
  profile = "aws-admin"
}
