output "lambda_exec_role_arn" {
  value = aws_iam_role.lambda_exec_role.arn
}

output "iot_dynamodb_role_arn" {
  value = aws_iam_role.iot_dynamodb_role.arn
}

output "iot_cwlogs_role_arn" {
  value = aws_iam_role.iot_cwlogs_role.arn
}
