output "mqtt_broker_uri" {
  value = module.iot.mqtt_broker_uri
}

output "mqtt_client_id" {
  value = module.iot.mqtt_client_id
}

output "mqtt_topic" {
  value = module.iot.mqtt_topic
}

output "http_api_invoke_url" {
  value = module.apigateway.http_api_invoke_url
}
