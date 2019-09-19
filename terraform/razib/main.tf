provider "aws" {
  region = "us-west-1"
}


terraform {
  backend "s3" {
    bucket = "precisely-terraform-state-biodev"
    key = "razib/terraform.tfstate"
    region = "us-west-1" # save all TF state in us-west-1, not the CF region!
    dynamodb_table = "terraform-locks-biodev"
    encrypt = true
  }
}


variable "machine_count" {
  type = number
  default = 1
}


variable "ebs_size_gb" {
  type = number
  default = 1005
}


module "cluster" {
  source = "../modules/compute-farm"

  cluster_name = "razib-cf-cluster"
  availability_zone = "us-west-1a"
  instance_type = "m5.16xlarge"
  machine_count = var.machine_count
  ssh_public_key_path = "/Users/razibkhan/.ssh/precisely_aws_biodev.pub"
  ebs_size_gb = var.ebs_size_gb
  data_s3_bucket = "precisely-bio-data-norcal"
}
