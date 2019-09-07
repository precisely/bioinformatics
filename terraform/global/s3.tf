resource "aws_s3_bucket" "biodev_data" {
  bucket = "precisely-bio-data"

  lifecycle {
    # prevent accidental deletion
    prevent_destroy = true
  }
}
