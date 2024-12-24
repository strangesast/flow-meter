variable "iot_topic_pattern" {
  description = "The IoT topic pattern to pass to DynamoDB."
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table."
  type        = string
}

variable "iot_dynamodb_role_arn" {
  description = "ARN of the IoT DynamoDB role."
  type        = string
}

variable "iot_cwlogs_role_arn" {
  description = "ARN of the IoT CloudWatch Logs role."
  type        = string
}

variable "iot_errors_log_group_name" {
  description = "Name of the IoT errors CloudWatch log group."
  type        = string
}
