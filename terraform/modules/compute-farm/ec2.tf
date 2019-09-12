# the latest base AMI for Ubuntu 18.04 LTS
data "aws_ami" "ubuntu_1804lts" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


# the latest Precise.ly compute farm (cf) AMI
data "aws_ami" "precisely_cf" {
  most_recent = true
  filter {
    name = "name"
    values = ["precisely-cf-*"]
  }
  owners = ["324503128200"] # Precise.ly
}


resource "aws_key_pair" "ssh" {
  key_name = "${var.cluster_name} SSH key"
  public_key = "${file(var.ssh_public_key_path)}"
}


resource "aws_launch_configuration" "compute_farm" {
  image_id = "${data.aws_ami.precisely_cf.id}"
  instance_type = var.instance_type
  key_name = "${aws_key_pair.ssh.key_name}"
  security_groups = [
    "${aws_security_group.out_all.id}",
    "${aws_security_group.in_ssh_6601_mosh_60000.id}",
    "${aws_security_group.in_lustre.id}"
  ]
}


resource "aws_autoscaling_group" "compute_farm" {
  launch_configuration = aws_launch_configuration.compute_farm.name

  vpc_zone_identifier = ["${aws_subnet.main.id}"]

  min_size = 1
  desired_capacity = var.machine_count
  max_size = 5

  tag {
    key = "Name"
    value = var.cluster_name
    propagate_at_launch = true
  }
}
