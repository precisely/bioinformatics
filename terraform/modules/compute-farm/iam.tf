data "aws_caller_identity" "current" {}


locals {
  account_id = "${data.aws_caller_identity.current.account_id}"
}


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
  name = "cf_node"
  path = "/"
  assume_role_policy = "${data.aws_iam_policy_document.cf_node.json}"
}


data "aws_iam_policy_document" "yas3fs" {
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
      "arn:aws:s3:::${var.data_s3_bucket}",
      "arn:aws:s3:::${var.data_s3_bucket}/*"
    ]
  }
  # SNS
  statement {
    actions = [
      "sns:ConfirmSubscription",
      "sns:GetTopicAttributes",
      "sns:Publish",
      "sns:Subscribe",
      "sns:Unsubscribe"
    ]
    resources = ["arn:aws:sns:*:${local.account_id}:*"]
  }
  # SQS
  statement {
    actions = [
      "sqs:CreateQueue",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
      "sqs:SetQueueAttributes",
      "sqs:SendMessage"
    ]
    resources = ["arn:aws:sqs:*:${local.account_id}:*"]
  }
  # IAM
  statement {
    actions = ["iam:GetUser"]
    resources = ["*"]
  }
}


resource "aws_iam_policy" "yas3fs" {
  name = "yas3fs"
  policy = "${data.aws_iam_policy_document.yas3fs.json}"
}


resource "aws_iam_role_policy_attachment" "test-attach" {
  role = "${aws_iam_role.cf_node.name}"
  policy_arn = "${aws_iam_policy.yas3fs.arn}"
}


resource "aws_iam_instance_profile" "cf_node" {
  name = "cf_node"
  role = "${aws_iam_role.cf_node.name}"
}
