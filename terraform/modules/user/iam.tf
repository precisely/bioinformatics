data "aws_caller_identity" "current" {}


data "aws_iam_policy_document" "cf_node" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}


resource "aws_iam_role" "cf_node" {
  name = "cf-node-${var.name}"
  path = "/"
  assume_role_policy = data.aws_iam_policy_document.cf_node.json
}


data "aws_iam_policy_document" "s3_base" {
  # S3
  statement {
    actions = [
      "s3:GetBucketLocation",
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket",
      "s3:PutObject"
    ]
    resources = [
      # TODO: Find a way to fix the ugly bucket enumeration.
      "arn:aws:s3:::precisely-bio-data-norcal",
      "arn:aws:s3:::precisely-bio-data-norcal/*",
      "arn:aws:s3:::precisely-bio-data-oregon",
      "arn:aws:s3:::precisely-bio-data-oregon/*",
      "arn:aws:s3:::precisely-bio-data-sydney",
      "arn:aws:s3:::precisely-bio-data-sydney/*"
    ]
  }
  # IAM
  statement {
    actions = ["iam:GetUser"]
    resources = ["*"]
  }
}


resource "aws_iam_policy" "s3_base" {
  name = "s3-base-${var.name}"
  policy = data.aws_iam_policy_document.s3_base.json
}


resource "aws_iam_role_policy_attachment" "s3_base" {
  role = aws_iam_role.cf_node.name
  policy_arn = aws_iam_policy.s3_base.arn
}


resource "aws_iam_instance_profile" "cf_node" {
  name = "cf-node-${var.name}"
  role = aws_iam_role.cf_node.name
}
