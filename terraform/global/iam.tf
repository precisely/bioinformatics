### users

resource "aws_iam_user" "aneil" {
  name = "aneil"
  path = "/"
}

resource "aws_iam_user" "cv" {
  name = "cv"
  path = "/"
}

resource "aws_iam_user" "rick" {
  name = "rick"
  path = "/"
}

resource "aws_iam_user" "razib" {
  name = "razib"
  path = "/"
}


### group: administrators

resource "aws_iam_group" "administrators" {
  name = "Administrators"
  path = "/"
}

resource "aws_iam_group_membership" "administrators" {
  name = "administrators"
  group = "${aws_iam_group.administrators.name}"
  users = [
    "${aws_iam_user.aneil.name}",
    "${aws_iam_user.cv.name}"
  ]
}

resource "aws_iam_group_policy_attachment" "administrators-AdministratorAccess" {
  group = "${aws_iam_group.administrators.name}"
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}


### group: developers

resource "aws_iam_group" "developers" {
  name = "Developers"
  path = "/"
}

resource "aws_iam_group_membership" "developers" {
  name = "developers"
  group = "${aws_iam_group.developers.name}"
  users = [
    "${aws_iam_user.aneil.name}",
    "${aws_iam_user.cv.name}",
    "${aws_iam_user.rick.name}",
    "${aws_iam_user.razib.name}"
  ]
}

resource "aws_iam_group_policy_attachment" "developers-IAMUserChangePassword" {
  group = "${aws_iam_group.developers.name}"
  policy_arn = "arn:aws:iam::aws:policy/IAMUserChangePassword"
}

resource "aws_iam_group_policy_attachment" "developers-AmazonEC2FullAccess" {
  group = "${aws_iam_group.developers.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_group_policy_attachment" "developers-EC2InstanceConnect" {
  group = "${aws_iam_group.developers.name}"
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceConnect"
}

resource "aws_iam_group_policy_attachment" "developers-AmazonS3FullAccess" {
  group = "${aws_iam_group.developers.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_group_policy_attachment" "developers-AmazonDynamoDBFullAccess" {
  group = "${aws_iam_group.developers.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_group_policy_attachment" "developers-AmazonRDSFullAccess" {
  group = "${aws_iam_group.developers.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
}

resource "aws_iam_group_policy_attachment" "developers-CloudWatchFullAccess" {
  group = "${aws_iam_group.developers.name}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}
