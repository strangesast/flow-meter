TODO:
- [ ] assign name
- [ ] write to appropriate MQTT topic
- [ ] test WiFi reconnection
- [ ] valve control (sub to MQTT topic)

TODO (aspirational):
- [ ] bluetooth status
- [ ] bluetooth control


```
# set target
idf.py set-target esp32

# flash and monitor
idf.py -p PORT flash monitor
idf.py -p /dev/cu.usbserial-0001 flash

# list things
aws iot list-things
```
