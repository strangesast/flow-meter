data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = local.source_dir
  excludes    = ["${local.source_dir}/env"]
  output_path = "${path.module}/../${var.lambda_file_name}"
}

resource "aws_lambda_function" "example_http_lambda" {
  function_name    = var.function_name
  role             = var.lambda_exec_role_arn
  runtime          = var.runtime
  handler          = var.handler
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_log_group]
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 7
}
