#!/bin/bash
MQTT_BROKER_URI=$(terraform -chdir=.. output -raw mqtt_broker_uri) node test.js
