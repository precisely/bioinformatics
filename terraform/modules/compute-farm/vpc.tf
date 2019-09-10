data "aws_vpc" "default" {
  default = true
}


data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}


resource "aws_security_group" "out_all" {
  name = "${var.cluster_name}-out-all"
  description = "Outbound: allow all"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "in_ssh_6601_mosh_60000" {
  name = "${var.cluster_name}-ssh-6601"
  description = "Inbound: allow SSH (6601) and Mosh"

  # FIXME: Remove this.
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ssh over TCP port 6601
  ingress {
    from_port = 6601
    to_port = 6601
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # mosh over UDP
  ingress {
    from_port = 60000
    to_port = 61000
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
