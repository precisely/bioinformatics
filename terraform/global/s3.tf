resource "aws_s3_bucket" "biodev_data_norcal" {
  bucket = "precisely-bio-data-norcal"
  provider = aws.norcal
  region = "us-west-1"

  lifecycle {
    # prevent accidental deletion
    prevent_destroy = true
  }
}


# for yas3fs
resource "aws_sns_topic" "biodev_data_norcal" {
  name = "s3-biodev-data-norcal"
  provider = aws.norcal
}


resource "aws_s3_bucket" "biodev_data_oregon" {
  bucket = "precisely-bio-data-oregon"
  provider = aws.oregon
  region = "us-west-2"

  lifecycle {
    # prevent accidental deletion
    prevent_destroy = true
  }
}


# for yas3fs
resource "aws_sns_topic" "biodev_data_oregon" {
  name = "s3-biodev-data-oregon"
  provider = aws.oregon
}


resource "aws_s3_bucket" "biodev_data_sydney" {
  bucket = "precisely-bio-data-sydney"
  provider = aws.sydney
  region = "ap-southeast-2"

  lifecycle {
    # prevent accidental deletion
    prevent_destroy = true
  }
}


# for yas3fs
resource "aws_sns_topic" "biodev_data_sydney" {
  name = "s3-biodev-data-sydney"
  provider = aws.sydney
}


output "biodev_data_s3_regions" {
  value = {
    "${aws_s3_bucket.biodev_data_norcal.bucket}" = "us-west-1"
    "${aws_s3_bucket.biodev_data_oregon.bucket}" = "us-west-2"
    "${aws_s3_bucket.biodev_data_sydney.bucket}" = "ap-southeast-2"
  }
}


output "biodev_data_s3_sns_arns" {
  value = {
    "${aws_s3_bucket.biodev_data_norcal.bucket}" = aws_sns_topic.biodev_data_norcal.arn
    "${aws_s3_bucket.biodev_data_oregon.bucket}" = aws_sns_topic.biodev_data_oregon.arn
    "${aws_s3_bucket.biodev_data_sydney.bucket}" = aws_sns_topic.biodev_data_sydney.arn
  }
}
