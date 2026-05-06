# S3 BUCKET

resource "aws_s3_bucket" "image_bucket" {
  bucket        = "image-processor-${terraform.workspace}-images-${random_id.suffix.hex}"
  force_destroy = true
  tags   = { Name = "s3-image-processor-${terraform.workspace}" }
}

resource "random_id" "suffix" {
  byte_length = 8
}

resource "aws_s3_bucket_versioning" "image_bucket_versioning" {
  bucket = aws_s3_bucket.image_bucket.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "image_bucket_encryption" {
  bucket = aws_s3_bucket.image_bucket.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "image_bucket_lifecycle" {
  bucket = aws_s3_bucket.image_bucket.id
  rule {
    id     = "expire-uploads"
    status = "Enabled"
    filter {
      prefix = "uploads/"
    }
    expiration { days = 30 }
  }
  rule {
    id     = "expire-processed"
    status = "Enabled"
    filter {
      prefix = "processed/"
    }
    expiration { days = 90 }
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.image_bucket.id
  queue {
    queue_arn     = aws_sqs_queue.image_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/"
  }
  depends_on = [aws_sqs_queue_policy.default]
}

# SQS & CLOUDWATCH

resource "aws_sqs_queue" "image_queue_dlq" {
  name                      = "image-processor-${terraform.workspace}-image-dlq"
  message_retention_seconds = 1209600 # 14 days
  tags                      = { Name = "sqs-dlq-${var.project_name}-${terraform.workspace}" }
}

resource "aws_sqs_queue" "image_queue" {
  name                       = "image-processor-${terraform.workspace}-image-queue"
  message_retention_seconds  = 86400 # 1 day
  receive_wait_time_seconds  = 20
  visibility_timeout_seconds = 360
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.image_queue_dlq.arn
    maxReceiveCount     = 3
  })
  tags = { Name = "sqs-queue-${var.project_name}-${terraform.workspace}" }
}

resource "aws_sqs_queue_policy" "default" {
  queue_url = aws_sqs_queue.image_queue.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.image_queue.arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_s3_bucket.image_bucket.arn } }
    }]
  })
}

resource "aws_cloudwatch_metric_alarm" "dlq_alarm" {
  alarm_name          = "dlq-messages-alarm-${terraform.workspace}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alarm when DLQ has visible messages"
  dimensions          = { QueueName = aws_sqs_queue.image_queue_dlq.name }
}
