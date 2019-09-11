resource "aws_s3_bucket" "biodev_data_norcal" {
  bucket = "precisely-bio-data-norcal"
  region = "us-west-1"

  lifecycle {
    # prevent accidental deletion
    prevent_destroy = true
  }
}


resource "aws_s3_bucket" "biodev_data_sydney" {
  bucket = "precisely-bio-data-sydney"
  provider = "aws.sydney"
  region = "ap-southeast-2"

  lifecycle {
    # prevent accidental deletion
    prevent_destroy = true
  }
}
