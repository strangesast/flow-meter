output "table_arn" {
  value = aws_dynamodb_table.flow_meter_data_table.arn
}

output "table_name" {
  value = aws_dynamodb_table.flow_meter_data_table.name
}
