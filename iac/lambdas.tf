# LAMBDA FUNCTIONS

data "archive_file" "upload_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../lambdas/upload"
  output_path = "${path.module}/upload.zip"
}

resource "aws_lambda_function" "upload_lambda" {
  function_name    = "lambda-upload-${var.project_name}-${terraform.workspace}"
  role             = aws_iam_role.upload_lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  memory_size      = 256
  timeout          = 30
  filename         = data.archive_file.upload_lambda_zip.output_path
  source_code_hash = data.archive_file.upload_lambda_zip.output_base64sha256
  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda.id]
  }
  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.image_bucket.bucket
      UPLOAD_PREFIX = "uploads/"
    }
  }
  tags = { Name = "lambda-upload-${var.project_name}-${terraform.workspace}" }
}

data "archive_file" "crop_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../lambdas/crop"
  output_path = "${path.module}/crop.zip"
}

resource "aws_lambda_function" "crop_lambda" {
  function_name    = "lambda-crop-${var.project_name}-${terraform.workspace}"
  role             = aws_iam_role.crop_lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  memory_size      = 512
  timeout          = 60
  filename         = data.archive_file.crop_lambda_zip.output_path
  source_code_hash = data.archive_file.crop_lambda_zip.output_base64sha256
  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda.id]
  }
  environment {
    variables = {
      S3_BUCKET        = aws_s3_bucket.image_bucket.bucket
      PROCESSED_PREFIX = "processed/"
    }
  }
  tags = { Name = "lambda-crop-${var.project_name}-${terraform.workspace}" }
}

# LAMBDA TRIGGERS & LOGS

resource "aws_lambda_event_source_mapping" "crop_lambda_sqs_mapping" {
  event_source_arn        = aws_sqs_queue.image_queue.arn
  function_name           = aws_lambda_function.crop_lambda.arn
  batch_size              = 5
  function_response_types = ["ReportBatchItemFailures"]
}

resource "aws_cloudwatch_log_group" "upload_lambda_lg" {
  name              = "/aws/lambda/${aws_lambda_function.upload_lambda.function_name}"
  retention_in_days = 14
  tags              = { Name = "lg-upload-${var.project_name}-${terraform.workspace}" }
}

resource "aws_cloudwatch_log_group" "crop_lambda_lg" {
  name              = "/aws/lambda/${aws_lambda_function.crop_lambda.function_name}"
  retention_in_days = 14
  tags              = { Name = "lg-crop-${var.project_name}-${terraform.workspace}" }
}
