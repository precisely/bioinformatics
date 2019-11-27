# the latest base AMI for Ubuntu 18.04 LTS
data "aws_ami" "ubuntu_1804lts" {
  most_recent = true

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


# the latest base AMI for Amazon Linux 2
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  filter {
    name = "name"
    values = ["amzn2-ami-hvm-2.0.????????-x86_64-gp2"]
  }
  owners = ["amazon"]
}


# the latest Precise.ly compute farm (cf) AMI
data "aws_ami" "precisely_cf" {
  most_recent = true
  filter {
    name = "name"
    values = ["precisely-research-node-*"]
  }
  owners = ["324503128200"] # Precise.ly
}


resource "aws_key_pair" "ssh" {
  key_name = "${var.cluster_name} SSH key"
  public_key = file(var.ssh_public_key_path)
}


data "template_file" "bootstrap" {
  template = file("../modules/compute-farm/files/bootstrap")
  vars = {
    region = data.terraform_remote_state.global.outputs.biodev_data_s3_regions[var.data_s3_bucket]
    data_s3_bucket = var.data_s3_bucket
    data_sns_topic_arn = data.terraform_remote_state.global.outputs.biodev_data_s3_sns_arns[var.data_s3_bucket]
  }
}


resource "aws_launch_configuration" "compute_farm" {
  image_id = data.aws_ami.precisely_cf.id
  instance_type = var.instance_type
  key_name = aws_key_pair.ssh.key_name
  security_groups = [aws_security_group.node.id]
  iam_instance_profile = aws_iam_instance_profile.cf_node.name
  ebs_block_device {
    device_name = "/dev/xvdf"
    volume_type = "gp2"
    volume_size = var.ebs_size_gb
    delete_on_termination = true
  }
  # lifecycle {
  #   create_before_destroy = true
  # }
  user_data = data.template_file.bootstrap.rendered
}


resource "aws_autoscaling_group" "compute_farm" {
  launch_configuration = aws_launch_configuration.compute_farm.name

  vpc_zone_identifier = [aws_subnet.main.id]

  min_size = 1
  desired_capacity = var.machine_count
  max_size = 5

  tag {
    key = "Name"
    value = var.cluster_name
    propagate_at_launch = true
  }
}
