/* MQTT Mutual Authentication Example

   This example code is in the Public Domain (or CC0 licensed, at your option.)

   Unless required by applicable law or agreed to in writing, this
   software is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
   either express or implied.
*/

#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <sys/time.h>
#include "esp_wifi.h"
#include "esp_system.h"
#include "nvs_flash.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "protocol_examples_common.h"

#include "driver/gpio.h"

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"
#include "freertos/queue.h"

#include "lwip/sockets.h"
#include "lwip/dns.h"
#include "lwip/netdb.h"

#include "esp_log.h"
#include "mqtt_client.h"

/* New SNTP includes (ESP-IDF v5+). */
#include "esp_netif_sntp.h"


#define PULSE_INPUT_PIN GPIO_NUM_25
#define PULSE_INTERVAL_MS 1000
#define TOGGLE_PIN GPIO_NUM_27
#define TOGGLE_INTERVAL_MS 10000
#define MQTT_TOPIC "sdk/test/js"
#define MQTT_CLIENT_ID "example_iot_device"
#define MQTT_BROKER_URI "mqtts://a3ef0ftua30ffm-ats.iot.us-east-1.amazonaws.com"
#define MQTT_BROKER_PORT 8883

static const char *TAG = "MQTTS_EXAMPLE";

extern const uint8_t client_cert_pem_start[] asm("_binary_client_crt_start");
extern const uint8_t client_cert_pem_end[]   asm("_binary_client_crt_end");
extern const uint8_t client_key_pem_start[]  asm("_binary_client_key_start");
extern const uint8_t client_key_pem_end[]    asm("_binary_client_key_end");
extern const uint8_t server_cert_pem_start[] asm("_binary_root_crt_start");
extern const uint8_t server_cert_pem_end[]   asm("_binary_root_crt_end");


static void log_error_if_nonzero(const char *message, int error_code)
{
    if (error_code != 0) {
        ESP_LOGE(TAG, "Last error %s: 0x%x", message, error_code);
    }
}

static volatile uint32_t pulse_count = 0;
static SemaphoreHandle_t pulse_mutex;
static esp_mqtt_client_handle_t mqtt_client = NULL;

static void IRAM_ATTR pulse_isr_handler(void *arg)
{
    if (pulse_mutex && xSemaphoreTakeFromISR(pulse_mutex, NULL) == pdTRUE) {
        pulse_count++;
        xSemaphoreGiveFromISR(pulse_mutex, NULL);
    }
}

static void pulse_counter_task(void *arg)
{
    char message[64];
    TickType_t xLastWakeTime = xTaskGetTickCount();
    const TickType_t xFrequency = pdMS_TO_TICKS(PULSE_INTERVAL_MS);

    while (1) {
        vTaskDelayUntil(&xLastWakeTime, xFrequency);
        if (pulse_mutex && xSemaphoreTake(pulse_mutex, portMAX_DELAY)) {
            struct timeval tv;
            gettimeofday(&tv, NULL);
            time_t now = tv.tv_sec;

            // Construct the message to include pulse count and current epoch time
            snprintf(
                message,
                sizeof(message),
                "{\"pulse_count\": %" PRIu32 ", \"epoch_time\": %ld}",
                pulse_count,
                (long)now
            );
            ESP_LOGI(TAG, "%s", message);

            if (mqtt_client) {
                // esp_mqtt_client_enqueue(mqtt_client, MQTT_TOPIC, message, 0, 1, 1, true);
                esp_mqtt_client_publish(mqtt_client, MQTT_TOPIC, message, 0, 1, 1);
            }
            printf("message=%s\r\n", message);
            pulse_count = 0;
            xSemaphoreGive(pulse_mutex);
        }
    }
}

static void setup_pulse_counter(void)
{
    gpio_config_t io_conf = {
        .intr_type = GPIO_INTR_POSEDGE,
        .mode = GPIO_MODE_INPUT,
        .pin_bit_mask = (1ULL << PULSE_INPUT_PIN),
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .pull_up_en = GPIO_PULLUP_ENABLE
    };
    gpio_config(&io_conf);

    gpio_install_isr_service(ESP_INTR_FLAG_LEVEL3);
    gpio_isr_handler_add(PULSE_INPUT_PIN, pulse_isr_handler, NULL);

    pulse_mutex = xSemaphoreCreateMutex();
    if (pulse_mutex == NULL) {
        ESP_LOGE(TAG, "Failed to create pulse mutex");
    }

    xTaskCreate(pulse_counter_task, "pulse_counter_task", 2048, NULL, 10, NULL);
}

static void toggle_gpio_task(void *arg)
{
    gpio_config_t io_conf = {
        .mode = GPIO_MODE_OUTPUT,
        .pin_bit_mask = (1ULL << TOGGLE_PIN),
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .intr_type = GPIO_INTR_DISABLE
    };
    gpio_config(&io_conf);

    TickType_t xLastWakeTime = xTaskGetTickCount();
    const TickType_t xFrequency = pdMS_TO_TICKS(TOGGLE_INTERVAL_MS);

    while (1) {
        gpio_set_level(TOGGLE_PIN, 1);
        vTaskDelay(pdMS_TO_TICKS(TOGGLE_INTERVAL_MS / 2));
        gpio_set_level(TOGGLE_PIN, 0);
        vTaskDelayUntil(&xLastWakeTime, xFrequency);
    }
}

static void mqtt_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data)
{
    ESP_LOGD(TAG, "Event dispatched from event loop base=%s, event_id=%" PRIi32, base, event_id);
    esp_mqtt_event_handle_t event = event_data;
    esp_mqtt_client_handle_t client = event->client;
    int msg_id;

    const char *topic0 = MQTT_TOPIC;

    switch ((esp_mqtt_event_id_t)event_id) {
    case MQTT_EVENT_CONNECTED:
        ESP_LOGI(TAG, "MQTT_EVENT_CONNECTED");
        msg_id = esp_mqtt_client_subscribe(client, topic0, 0);
        ESP_LOGI(TAG, "sent subscribe successful, msg_id=%d", msg_id);
        break;
    case MQTT_EVENT_DISCONNECTED:
        ESP_LOGI(TAG, "MQTT_EVENT_DISCONNECTED");
        break;
    case MQTT_EVENT_SUBSCRIBED:
        ESP_LOGI(TAG, "MQTT_EVENT_SUBSCRIBED, msg_id=%d", event->msg_id);
        msg_id = esp_mqtt_client_publish(client, topic0, "data", 0, 0, 0);
        ESP_LOGI(TAG, "sent publish successful, msg_id=%d", msg_id);
        break;
    case MQTT_EVENT_UNSUBSCRIBED:
        ESP_LOGI(TAG, "MQTT_EVENT_UNSUBSCRIBED, msg_id=%d", event->msg_id);
        break;
    case MQTT_EVENT_PUBLISHED:
        ESP_LOGI(TAG, "MQTT_EVENT_PUBLISHED, msg_id=%d", event->msg_id);
        break;
    case MQTT_EVENT_DATA:
        ESP_LOGI(TAG, "MQTT_EVENT_DATA");
        printf("TOPIC=%.*s\r\n", event->topic_len, event->topic);
        printf("DATA=%.*s\r\n", event->data_len, event->data);
        break;
    case MQTT_EVENT_ERROR:
        ESP_LOGI(TAG, "MQTT_EVENT_ERROR");
        if (event->error_handle->error_type == MQTT_ERROR_TYPE_TCP_TRANSPORT) {
            log_error_if_nonzero("reported from esp-tls", event->error_handle->esp_tls_last_esp_err);
            log_error_if_nonzero("reported from tls stack", event->error_handle->esp_tls_stack_err);
            log_error_if_nonzero("captured as transport's socket errno",  event->error_handle->esp_transport_sock_errno);
            ESP_LOGI(TAG, "Last errno string (%s)", strerror(event->error_handle->esp_transport_sock_errno));
        }
        break;
    default:
        ESP_LOGI(TAG, "Other event id:%d", event->event_id);
        break;
    }
}

static void mqtt_app_start(void)
{
    const esp_mqtt_client_config_t mqtt_cfg = {
        .broker.address.uri = MQTT_BROKER_URI,
        .broker.address.port = MQTT_BROKER_PORT,
        .broker.verification.certificate = (const char *)server_cert_pem_start,
        .credentials = {
            .client_id = MQTT_CLIENT_ID,
            .authentication = {
                .certificate = (const char *)client_cert_pem_start,
                .key = (const char *)client_key_pem_start,
            },
        }
    };

    ESP_LOGI(TAG, "[APP] Free memory: %" PRIu32 " bytes", esp_get_free_heap_size());
    mqtt_client = esp_mqtt_client_init(&mqtt_cfg);
    esp_mqtt_client_register_event(mqtt_client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL);
    esp_mqtt_client_start(mqtt_client);
}

void app_main(void)
{
    ESP_LOGI(TAG, "[APP] Startup..");
    ESP_LOGI(TAG, "[APP] Free memory: %" PRIu32 " bytes", esp_get_free_heap_size());
    ESP_LOGI(TAG, "[APP] IDF version: %s", esp_get_idf_version());

    esp_log_level_set("*", ESP_LOG_INFO);
    esp_log_level_set("MQTT_CLIENT", ESP_LOG_VERBOSE);
    esp_log_level_set("TRANSPORT_BASE", ESP_LOG_VERBOSE);
    esp_log_level_set("TRANSPORT", ESP_LOG_VERBOSE);
    esp_log_level_set("OUTBOX", ESP_LOG_VERBOSE);

    ESP_ERROR_CHECK(nvs_flash_init());
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());


    ESP_LOGI(TAG, "Initializing SNTP");

    esp_sntp_config_t config = ESP_NETIF_SNTP_DEFAULT_CONFIG("pool.ntp.org");
    config.start = false;                       // start SNTP service explicitly (after connecting)
    config.server_from_dhcp = true;             // accept NTP offers from DHCP server, if any (need to enable *before* connecting)
    config.renew_servers_after_new_IP = true;   // let esp-netif update configured SNTP server(s) after receiving DHCP lease
    config.index_of_first_server = 1;           // updates from server num 1, leaving server 0 (from DHCP) intact
    config.ip_event_to_renew = IP_EVENT_STA_GOT_IP;


    esp_netif_sntp_init(&config);

    ESP_ERROR_CHECK(example_connect());

    esp_netif_sntp_start();
    int retry = 0;
    const int retry_count = 15;
    while (esp_netif_sntp_sync_wait(2000 / portTICK_PERIOD_MS) == ESP_ERR_TIMEOUT && ++retry < retry_count) {
        ESP_LOGI(TAG, "Waiting for system time to be set... (%d/%d)", retry, retry_count);
    }

    setup_pulse_counter();

    mqtt_app_start();

    xTaskCreate(toggle_gpio_task, "toggle_gpio_task", 2048, NULL, 5, NULL);
}
