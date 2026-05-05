provider "aws" {
  region = "us-east-1"
}

locals {
  env = terraform.workspace # Esto tomará "default", "dev", "qa", o "prod"
  prefix = "img-proc-${local.env}"
}

data "archive_file" "upload_zip" {
  type        = "zip"
  source_dir  = "../lambdas/upload"
  output_path = "${path.module}/upload.zip"
}

data "archive_file" "crop_zip" {
  type        = "zip"
  source_dir  = "../lambdas/crop"
  output_path = "${path.module}/crop.zip"
}