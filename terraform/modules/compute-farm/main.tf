### input variables

variable "cluster_name" {
  type = string
}

variable "instance_type" {
  type = string
  default = "t2.micro"
}

variable "availability_zone" {
  type = string
}

variable "machine_count" {
  type = number
}

variable "ssh_public_key_path" {
  type = string
}

variable "ebs_size_gb" {
  type = number
}

variable "data_s3_bucket" {
  type = string
}


### generic configuration

data "terraform_remote_state" "global" {
  backend = "s3"
  config = {
    bucket = "precisely-terraform-state-biodev"
    key = "global/terraform.tfstate"
    region = "us-west-1"
    dynamodb_table = "terraform-locks-biodev"
    encrypt = true
  }
}
