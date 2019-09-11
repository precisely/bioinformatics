# AWS region reference:
# - us-east-1: Virginia
# - us-east-2: Ohio
# - us-west-1: Northern California
# - us-west-2: Oregon
# - ap-southeast-1: Singapore
# - ap-southeast-2: Sydney
# - ap-south-1: Mumbai


provider "aws" {
  region = "us-west-1"
}


provider "aws" {
  region = "us-west-2"
  alias = "oregon"
}


provider "aws" {
  region = "ap-southeast-2"
  alias = "sydney"
}


resource "aws_s3_bucket" "terraform_state_biodev" {
  bucket = "precisely-terraform-state-biodev"

  lifecycle {
    # prevent accidental deletion
    prevent_destroy = true
  }

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}


resource "aws_dynamodb_table" "terraform_locks_biodev" {
  name = "terraform-locks-biodev"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}


terraform {
  backend "s3" {
    bucket = "precisely-terraform-state-biodev"
    key = "global/terraform.tfstate"
    region = "us-west-1"
    dynamodb_table = "terraform-locks-biodev"
    encrypt = true
  }
}
