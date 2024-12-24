output "mqtt_broker_uri" {
  value = data.aws_iot_endpoint.iot.endpoint_address
}

output "mqtt_client_id" {
  value = aws_iot_thing.flow_meter.name
}

output "mqtt_topic" {
  value = var.iot_topic_pattern
}
