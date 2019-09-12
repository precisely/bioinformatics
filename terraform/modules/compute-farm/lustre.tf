resource "aws_fsx_lustre_file_system" "lfs" {
  storage_capacity = var.lfs_size_gb
  #import_path = "s3://${var.lfs_s3_bucket}"
  #export_path = "???"
  subnet_ids = ["${aws_subnet.main.id}"]
}
