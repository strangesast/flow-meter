module "iot" {
  source    = "./modules/iot"
  iot_topic_pattern = var.iot_topic_pattern
  dynamodb_table_name     = var.dynamodb_table_name
  iot_dynamodb_role_arn   = module.iam.iot_dynamodb_role_arn
  iot_cwlogs_role_arn     = module.iam.iot_cwlogs_role_arn
  iot_errors_log_group_name = module.cloudwatch.iot_errors_log_group_name
}

module "dynamodb" {
  source     = "./modules/dynamodb"
  table_name = var.dynamodb_table_name
}

module "iam" {
  source             = "./modules/iam"
  dynamodb_table_arn = module.dynamodb.table_arn
}

module "lambda" {
  source               = "./modules/lambda"
  lambda_exec_role_arn = module.iam.lambda_exec_role_arn
  dynamodb_table_name  = var.dynamodb_table_name
}

module "apigateway" {
  source              = "./modules/apigateway"
  lambda_invoke_arn   = module.lambda.lambda_invoke_arn
  lambda_function_arn = module.lambda.lambda_function_arn
}

module "cloudwatch" {
  source = "./modules/cloudwatch"
}
