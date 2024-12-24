locals {
  dynamodb_table_name  = "IoTData"
  lambda_function_name = "http_lambda"
  lambda_handler       = "main.handler"
  lambda_runtime       = "python3.13"
  lambda_file_name     = "lambda_function.zip"
  lambda_source_dir    = "${path.module}/lambda_source"
}

provider "aws" {
  region = "us-east-1"
}

# Existing Resources...

resource "aws_iot_thing" "flow_meter" {
  name = "example_iot_device"
}

data "aws_iam_policy_document" "iot_policy" {
  statement {
    actions   = ["iot:*"]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iot_policy" "policy" {
  name   = "example_iot_policy"
  policy = data.aws_iam_policy_document.iot_policy.json
}

resource "aws_iot_certificate" "cert" {
  active = true
}

resource "aws_iot_thing_principal_attachment" "attachment" {
  thing     = aws_iot_thing.flow_meter.name
  principal = aws_iot_certificate.cert.arn
}

resource "aws_iot_policy_attachment" "attachment" {
  policy = aws_iot_policy.policy.name
  target = aws_iot_certificate.cert.arn
}

resource "aws_dynamodb_table" "flow_meter_data_table" {
  name         = local.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  range_key    = "timestamp"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }
}

data "aws_iam_policy_document" "iot_dynamodb_role" {
  version = "2012-10-17"

  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["iot.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iot_dynamodb_role" {
  name               = "iot_dynamodb_role"
  assume_role_policy = data.aws_iam_policy_document.iot_dynamodb_role.json
}

data "aws_iam_policy_document" "iot_dynamodb_policy" {
  version = "2012-10-17"
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "iot_dynamodb_policy" {
  name   = "iot_dynamodb_policy"
  role   = aws_iam_role.iot_dynamodb_role.id
  policy = data.aws_iam_policy_document.iot_dynamodb_policy.json
}

data "aws_iam_policy_document" "iot_cwlogs_role" {
  version = "2012-10-17"

  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["iot.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iot_cwlogs_role" {
  name               = "iot_cwlogs_role"
  assume_role_policy = data.aws_iam_policy_document.iot_cwlogs_role.json
}

data "aws_iam_policy_document" "iot_cwlogs_policy" {
  version = "2012-10-17"

  statement {
    effect    = "Allow"
    actions   = ["logs:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "iot_cwlogs_policy" {
  name   = "iot_cwlogs_policy"
  role   = aws_iam_role.iot_cwlogs_role.id
  policy = data.aws_iam_policy_document.iot_cwlogs_policy.json
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${local.lambda_function_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "iot_errors" {
  name              = "/aws/iot/error-logs"
  retention_in_days = 7
}

resource "aws_iot_topic_rule" "example_rule" {
  name        = "iot_to_dynamodb_rule"
  enabled     = true
  sql         = "SELECT * FROM '${var.iot_topic}'"
  sql_version = "2016-03-23"

  dynamodb {
    table_name      = aws_dynamodb_table.flow_meter_data_table.name
    role_arn        = aws_iam_role.iot_dynamodb_role.arn
    hash_key_field  = "id"
    hash_key_type   = "STRING"
    hash_key_value  = "$${topic()}"
    range_key_type  = "NUMBER"
    range_key_field = "timestamp"
    range_key_value = "$${timestamp()}"
    payload_field   = "payload"
    operation       = "INSERT"
  }

  error_action {
    cloudwatch_logs {
      role_arn       = aws_iam_role.iot_cwlogs_role.arn
      log_group_name = aws_cloudwatch_log_group.iot_errors.name
    }
  }
}

data "aws_iot_endpoint" "iot" {
  endpoint_type = "iot:Data-ATS"
}

data "http" "amazon_root_ca" {
  url = "https://www.amazontrust.com/repository/AmazonRootCA1.pem"
}

resource "local_file" "aws_root_cert" {
  content  = data.http.amazon_root_ca.response_body
  filename = "${path.module}/driver/main/root.crt"
}

resource "local_file" "device_cert" {
  content  = aws_iot_certificate.cert.certificate_pem
  filename = "${path.module}/driver/main/client.crt"
}

resource "local_file" "device_key" {
  content  = aws_iot_certificate.cert.private_key
  filename = "${path.module}/driver/main/client.key"
}

output "mqtt_broker_uri" {
  value = data.aws_iot_endpoint.iot.endpoint_address
}

output "mqtt_client_id" {
  value = aws_iot_thing.flow_meter.name
}

output "mqtt_topic" {
  value = var.iot_topic
}

# Lambda IAM Role and Policies

data "aws_iam_policy_document" "lambda_trust_policy" {
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name               = "lambda_exec_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach DynamoDB Query Permissions to Lambda Role
data "aws_iam_policy_document" "lambda_dynamodb_policy" {
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:Query", "dynamodb:GetItem", "dynamodb:Scan"]
    resources = [aws_dynamodb_table.flow_meter_data_table.arn]
  }
}

resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name   = "lambda_dynamodb_policy"
  role   = aws_iam_role.lambda_exec_role.id
  policy = data.aws_iam_policy_document.lambda_dynamodb_policy.json
}

# Archive the Lambda Source Code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = local.lambda_source_dir
  excludes    = ["${local.lambda_source_dir}/env"]
  output_path = "${path.module}/${local.lambda_file_name}"
}

# Lambda Function
resource "aws_lambda_function" "example_http_lambda" {
  function_name    = local.lambda_function_name
  role             = aws_iam_role.lambda_exec_role.arn
  runtime          = local.lambda_runtime
  handler          = local.lambda_handler
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = local.dynamodb_table_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_log_group]
}

# API Gateway (HTTP API)
resource "aws_apigatewayv2_api" "http_api" {
  name          = "example_http_api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                = aws_apigatewayv2_api.http_api.id
  integration_type      = "AWS_PROXY"
  integration_method    = "POST"
  integration_uri       = aws_lambda_function.example_http_lambda.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "lambda_route_root" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "lambda_route_hello" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "http_api_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example_http_lambda.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

output "http_api_invoke_url" {
  description = "Invoke URL for the HTTP API (integrated with the example Lambda)."
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}

