variable "iot_topic_pattern" {
  type    = string
  default = "flowmeter/+/+"
}

variable "dynamodb_table_name" {
  type    = string
  default = "IoTData"
}
