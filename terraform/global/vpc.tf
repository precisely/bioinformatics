### reference

# resource "aws_vpc" "shared" {
#   cidr_block = "10.0.0.0/16"
#
#   tags = {
#     Name = "Shared"
#   }
# }


# resource "aws_internet_gateway" "shared" {
#   vpc_id = "${aws_vpc.shared.id}"
# }


# resource "aws_route" "internet_access" {
#   route_table_id = "${aws_vpc.shared.main_route_table_id}"
#   destination_cidr_block = "0.0.0.0/0"
#   gateway_id = "${aws_internet_gateway.shared.id}"
# }


# resource "aws_subnet" "shared" {
#   vpc_id = "${aws_vpc.shared.id}"
#   cidr_block = "10.0.0.0/24"
#   map_public_ip_on_launch = true
# }


# resource "aws_security_group" "out_all" {
#   name = "out-all"
#   description = "Outbound: allow all"
#   vpc_id = "${aws_vpc.shared.id}"
#
#   egress {
#     from_port = 0
#     to_port = 0
#     protocol = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }


# resource "aws_security_group" "in_ssh_6601_mosh_60000" {
#   name = "ssh-6601"
#   description = "Inbound: allow SSH (6601) and Mosh"
#   vpc_id = "${aws_vpc.shared.id}"
#
#   # ssh over TCP port 6601
#   ingress {
#     from_port = 6601
#     to_port = 6601
#     protocol = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   # mosh over UDP
#   ingress {
#     from_port = 60000
#     to_port = 61000
#     protocol = "udp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }
