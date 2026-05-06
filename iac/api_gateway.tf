# API GATEWAY

resource "aws_apigatewayv2_api" "main" {
  name          = "api-${var.project_name}-${terraform.workspace}"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST"]
    allow_headers = ["*"]
  }
  tags = { Name = "api-${var.project_name}-${terraform.workspace}" }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_lg.arn
    format = jsonencode({
      requestId    = "$context.requestId"
      sourceIp     = "$context.identity.sourceIp"
      requestTime  = "$context.requestTime"
      httpMethod   = "$context.httpMethod"
      resourcePath = "$context.resourcePath"
      status       = "$context.status"
      protocol     = "$context.protocol"
      })
  }
  tags = { Name = "stage-default-${var.project_name}-${terraform.workspace}" }
}

resource "aws_apigatewayv2_integration" "upload_lambda_integration" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.upload_lambda.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "upload_route" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.upload_lambda_integration.id}"
}

resource "aws_lambda_permission" "api_gw_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_cloudwatch_log_group" "api_gw_lg" {
  name              = "/aws/apigateway/api-${var.project_name}-${terraform.workspace}"
  retention_in_days = 14
  tags              = { Name = "lg-apigw-${var.project_name}-${terraform.workspace}" }
}
