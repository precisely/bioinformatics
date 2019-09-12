resource "aws_fsx_lustre_file_system" "lfs" {
  storage_capacity = var.lfs_size_gb
  import_path = "s3://${var.lfs_s3_bucket}/"
  export_path = "s3://${var.lfs_s3_bucket}/"
  subnet_ids = ["${aws_subnet.main.id}"]
  security_group_ids = [
    "${aws_security_group.lustre.id}",
    "${aws_security_group.out_all.id}"
  ]
}
