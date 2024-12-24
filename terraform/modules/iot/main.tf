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


resource "aws_iot_topic_rule" "example_rule" {
  name        = "iot_to_dynamodb_rule"
  enabled     = true
  sql         = "SELECT * FROM '${var.iot_topic}'"
  sql_version = "2016-03-23"

  dynamodb {
    table_name      = var.dynamodb_table_name
    role_arn        = var.iot_dynamodb_role_arn
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
      role_arn       = var.iot_cwlogs_role_arn
      log_group_name = var.iot_errors_log_group_name
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
  filename = "${path.module}/../../../driver/main/root.crt"
}

resource "local_file" "device_cert" {
  content = aws_iot_certificate.cert.certificate_pem
  filename = "${path.module}/../../../driver/main/client.crt"
}

resource "local_file" "device_key" {
  content = aws_iot_certificate.cert.private_key
  filename = "${path.module}/../../../driver/main/client.key"
}
