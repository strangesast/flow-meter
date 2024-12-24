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

data "aws_iam_policy_document" "lambda_trust_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
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

data "aws_iam_policy_document" "lambda_dynamodb_policy" {
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:Query", "dynamodb:GetItem", "dynamodb:Scan"]
    resources = [var.dynamodb_table_arn]
  }
}

resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name   = "lambda_dynamodb_policy"
  role   = aws_iam_role.lambda_exec_role.id
  policy = data.aws_iam_policy_document.lambda_dynamodb_policy.json
}
