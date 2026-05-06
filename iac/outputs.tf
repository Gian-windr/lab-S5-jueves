output "api_endpoint" {
  description = "The invoke URL for the API Gateway"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "s3_bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.image_bucket.bucket
}
