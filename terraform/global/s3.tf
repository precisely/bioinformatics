resource "aws_s3_bucket" "biodev_data_norcal" {
  bucket = "precisely-bio-data-norcal"
  provider = aws.norcal
  region = "us-west-1"

  lifecycle {
    # prevent accidental deletion
    prevent_destroy = true
  }

  versioning {
    enabled = true
  }

  lifecycle_rule {
    prefix  = "/"
    enabled = true
    noncurrent_version_expiration {
      days = 30
    }
  }
}


resource "aws_s3_bucket" "biodev_data_oregon" {
  bucket = "precisely-bio-data-oregon"
  provider = aws.oregon
  region = "us-west-2"

  lifecycle {
    # prevent accidental deletion
    prevent_destroy = true
  }

  versioning {
    enabled = true
  }

  lifecycle_rule {
    prefix  = "/"
    enabled = true
    noncurrent_version_expiration {
      days = 30
    }
  }
}


resource "aws_s3_bucket" "biodev_data_sydney" {
  bucket = "precisely-bio-data-sydney"
  provider = aws.sydney
  region = "ap-southeast-2"

  lifecycle {
    # prevent accidental deletion
    prevent_destroy = true
  }

  versioning {
    enabled = true
  }

  lifecycle_rule {
    prefix  = "/"
    enabled = true
    noncurrent_version_expiration {
      days = 30
    }
  }
}


output "biodev_data_s3_regions" {
  value = {
    "${aws_s3_bucket.biodev_data_norcal.bucket}" = "us-west-1"
    "${aws_s3_bucket.biodev_data_oregon.bucket}" = "us-west-2"
    "${aws_s3_bucket.biodev_data_sydney.bucket}" = "ap-southeast-2"
  }
}
