variable "function_name" {
  default     = "flow_meter_http_lambda"
  description = "Name of the Lambda function."
  type        = string
}

variable "handler" {
  default     = "main.handler"
  description = "Lambda handler."
  type        = string
}

variable "runtime" {
  description = "Lambda runtime environment."
  default     = "python3.13"
  type        = string
}

variable "lambda_file_name" {
  description = "Name of the Lambda zip file."
  default     = "lambda_function.zip"
  type        = string
}

variable "lambda_exec_role_arn" {
  description = "ARN of the Lambda execution role."
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table."
  type        = string
}
