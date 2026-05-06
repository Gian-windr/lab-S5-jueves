# IAM ROLE FOR UPLOAD LAMBDA

resource "aws_iam_role" "upload_lambda_role" {
  name = "role-upload-lambda-${var.project_name}-${terraform.workspace}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
  tags = { Name = "role-upload-lambda-${var.project_name}-${terraform.workspace}" }
}

resource "aws_iam_role_policy_attachment" "upload_lambda_vpc_access" {
  role       = aws_iam_role.upload_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "upload_lambda_basic_execution" {
  role       = aws_iam_role.upload_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "upload_lambda_s3_policy" {
  name   = "policy-s3-upload-lambda-${var.project_name}-${terraform.workspace}"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Action   = ["s3:PutObject"]
      Effect   = "Allow"
      Resource = "${aws_s3_bucket.image_bucket.arn}/uploads/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "upload_lambda_s3" {
  role       = aws_iam_role.upload_lambda_role.name
  policy_arn = aws_iam_policy.upload_lambda_s3_policy.arn
}


# IAM ROLE FOR CROP LAMBDA

resource "aws_iam_role" "crop_lambda_role" {
  name = "role-crop-lambda-${var.project_name}-${terraform.workspace}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
  tags = { Name = "role-crop-lambda-${var.project_name}-${terraform.workspace}" }
}

resource "aws_iam_role_policy_attachment" "crop_lambda_vpc_access" {
  role       = aws_iam_role.crop_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "crop_lambda_basic_execution" {
  role       = aws_iam_role.crop_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "crop_lambda_s3_sqs_policy" {
  name   = "policy-s3-sqs-crop-lambda-${var.project_name}-${terraform.workspace}"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:GetObject"]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.image_bucket.arn}/uploads/*"
      },
      {
        Action   = ["s3:PutObject"]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.image_bucket.arn}/processed/*"
      },
      {
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Effect   = "Allow"
        Resource = aws_sqs_queue.image_queue.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "crop_lambda_s3_sqs" {
  role       = aws_iam_role.crop_lambda_role.name
  policy_arn = aws_iam_policy.crop_lambda_s3_sqs_policy.arn
}
