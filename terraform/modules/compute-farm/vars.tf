variable "cluster_name" {
  type = string
}


variable "instance_type" {
  type = string
  default = "t2.micro"
}


variable "machine_count" {
  type = number
}
