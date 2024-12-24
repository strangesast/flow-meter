output "lambda_invoke_arn" {
  value = aws_lambda_function.example_http_lambda.invoke_arn
}

output "lambda_function_arn" {
  value = aws_lambda_function.example_http_lambda.arn
}
