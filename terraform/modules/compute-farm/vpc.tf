resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name} Main"
  }
}


resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}


resource "aws_route" "internet_access" {
  route_table_id = aws_vpc.main.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.main.id
}


resource "aws_subnet" "main" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone = var.availability_zone
}


resource "aws_security_group" "node" {
  name = "${var.name}-node"
  description = "Compute farm node security group"

  vpc_id = aws_vpc.main.id

  # outbound: allow all
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self = true
  }

  # inbound: ssh over TCP port 6601
  ingress {
    from_port = 6601
    to_port = 6601
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # inbound: mosh over UDP
  ingress {
    from_port = 60000
    to_port = 61000
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
