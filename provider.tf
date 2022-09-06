terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.29.0"
    }
  }
}

provider "aws" {
  region     = "eu-west-2"
  access_key = var.access_key
  secret_key = var.secret_key
}