const mqtt = require('mqtt');
const fs = require('fs');

const KEY_PATH = '../driver/main/client.key';
const CERT_PATH = '../driver/main/client.crt';
const CA_PATH = '../driver/main/root.crt';
const MQTT_BROKER_URI = process.env.MQTT_BROKER_URI;
const TOPIC = 'sdk/test/js';

const client = mqtt.connect({
  host: MQTT_BROKER_URI,
  port: 8883,
  protocol: 'mqtts',
  key: fs.readFileSync(KEY_PATH),
  cert: fs.readFileSync(CERT_PATH),
  ca: fs.readFileSync(CA_PATH),
  rejectUnauthorized: true,
});

client.on('connect', () => {
  console.log('Connected.');

  /*
  client.publish(TOPIC, 'Hello from my new certificate!', (err) => {
    if (err) {
      console.error('Failed to publish:', err);
    } else {
      console.log(`Message published to topic "${TOPIC}" successfully.`);
    }
    client.end();
  });
  */

  client.subscribe(TOPIC, (err) => {
    if (err) {
      console.error('Failed to subscribe:', err);
    } else {
      console.log(`Subscribed to topic "${TOPIC}" successfully.`);
    }
    client.on('message', (topic, message) => {
      console.log(`Received message on topic "${topic}": ${message}`);
    })
    // client.end();
  });
});

client.on('error', (error) => {
  console.error('Connection error:', error);
});
