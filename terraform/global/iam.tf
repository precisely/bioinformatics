data "aws_caller_identity" "current" {}


### users

module "user_aneil" {
  source = "../modules/user"
  name = "aneil"
}

module "user_cv" {
  source = "../modules/user"
  name = "cv"
}

module "user_rick" {
  source = "../modules/user"
  name = "rick"
}

module "user_razib" {
  source = "../modules/user"
  name = "razib"
}

module "user_gareth" {
  source = "../modules/user"
  name = "gareth"
}


### group: administrators

resource "aws_iam_group" "administrators" {
  name = "Administrators"
  path = "/"
}

resource "aws_iam_group_membership" "administrators" {
  name = "administrators"
  group = aws_iam_group.administrators.name
  users = [
    "aneil",
    "cv"
  ]
}

resource "aws_iam_group_policy_attachment" "administrators-AdministratorAccess" {
  group = aws_iam_group.administrators.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}


### group: developers

resource "aws_iam_group" "developers" {
  name = "Developers"
  path = "/"
}

resource "aws_iam_group_membership" "developers" {
  name = "developers"
  group = aws_iam_group.developers.name
  users = [
    "aneil",
    "cv",
    "rick",
    "razib",
    "gareth"
  ]
}

resource "aws_iam_group_policy_attachment" "developers-IAMUserChangePassword" {
  group = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/IAMUserChangePassword"
}

resource "aws_iam_group_policy_attachment" "developers-IAMUserSSHKeys" {
  group = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/IAMUserSSHKeys"
}

resource "aws_iam_group_policy_attachment" "developers-IAMSelfManageServiceSpecificCredentials" {
  group = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/IAMSelfManageServiceSpecificCredentials"
}

resource "aws_iam_group_policy_attachment" "developers-AmazonEC2FullAccess" {
  group = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_group_policy_attachment" "developers-EC2InstanceConnect" {
  group = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceConnect"
}

resource "aws_iam_group_policy_attachment" "developers-AmazonS3FullAccess" {
  group = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_group_policy_attachment" "developers-AmazonDynamoDBFullAccess" {
  group = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_group_policy_attachment" "developers-AmazonRDSFullAccess" {
  group = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
}

resource "aws_iam_group_policy_attachment" "developers-CloudWatchFullAccess" {
  group = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_group_policy_attachment" "developers-pass_ec2_role" {
  group = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.pass_ec2_role.arn
}


### policy: passing a role

data "aws_iam_policy_document" "pass_ec2_role" {
  statement {
    actions = [
      "iam:GetRole",
      "iam:PassRole"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:*"
    ]
  }
}

resource "aws_iam_policy" "pass_ec2_role" {
  name = "cf-pass-ec2-role"
  policy = data.aws_iam_policy_document.pass_ec2_role.json
}
