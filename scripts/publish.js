const { setTimeout } = require('timers/promises');
const mqtt = require('mqtt');
const fs = require('fs');

const KEY_PATH = '../driver/main/client.key';
const CERT_PATH = '../driver/main/client.crt';
const CA_PATH = '../driver/main/root.crt';
const MQTT_BROKER_URI = process.env.MQTT_BROKER_URI;
const TOPIC = 'flowmeter/device0/valve_status';

const DEVICES = ['device0', 'device1'];

const client = mqtt.connect({
  host: MQTT_BROKER_URI,
  port: 8883,
  protocol: 'mqtts',
  key: fs.readFileSync(KEY_PATH),
  cert: fs.readFileSync(CERT_PATH),
  ca: fs.readFileSync(CA_PATH),
  rejectUnauthorized: true,
});

client.on('connect', async () => {
  console.log('Connected.');

  console.log(`Opening valves...`);
  for (const device of DEVICES) {
    await client.publishAsync(`flowmeter/${device}/valve_status`, "1");
  }

  console.log(`Getting some flow data...`);
  await client.subscribeAsync(`flowmeter/+/flow`);
  client.on('message', async (topic, message) => {
    console.log(message);
  });
  await setTimeout(20 * 1e3);
  await client.unsubscribeAsync(`flowmeter/+/flow`);

  console.log(`Closing valves...`);
  for (const device of DEVICES) {
    await client.publishAsync(`flowmeter/${device}/valve_status`, "0");
  }

  client.end();
});

client.on('error', (error) => {
  console.error('Connection error:', error);
});
