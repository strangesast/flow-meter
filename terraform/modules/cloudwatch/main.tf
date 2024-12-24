resource "aws_cloudwatch_log_group" "iot_errors" {
  name              = "/aws/iot/error-logs"
  retention_in_days = 7
}
