// Plant Device implementation - Configured state
#include "plant_device.h"
#include <WiFi.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include <PubSubClient.h>
#include <DHT.h>

// ============================================================================
// CONFIGURATION
// ============================================================================

static const char *PREF_NAMESPACE = "plantdev";
static const int LED_BUILTIN_PIN = 2;
static const int MOISTURE_SENSOR_PIN = 33;
static const int DHT_PIN = 19;

#define DHTTYPE DHT22
static DHT dht(DHT_PIN, DHTTYPE);

static const uint16_t MQTT_PORT = 1883;
static const char* MQTT_TOPIC_TELEMETRY = "telemetry";

// ============================================================================
// DEVICE GLOBALS
// ============================================================================

static Preferences preferences;
static String chipId;
static String deviceId;

// MQTT
static WiFiClient espClient;
static PubSubClient mqttClient(espClient);
static unsigned long lastPublish = 0;
static const unsigned long PUBLISH_INTERVAL = 10UL * 1000UL;

// Pump control state
static bool isPumping = false;
static float targetMoistureIncrease = 0.0;
static int baseMoisture = 0;
static unsigned long pumpStartTime = 0;
static const unsigned long MAX_PUMP_DURATION = 30000;

// ============================================================================
// FORWARD DECLARATIONS
// ============================================================================

static bool connectToHub();
static void sendMqttData(const String &topic, const String &payload);
static void receiveMqttData(char* topic, byte* payload, unsigned int length);
static void updatePumpStatus();
static void startPumping(float moistureDelta);
static void stopPumping();
static int getSoilMoisture();
static float getTemperature();
static float getHumidity();
static void sendMoistureData(int moisture);
static void sendTemperatureData(float temperature);
static void sendHumidityData(float humidity);

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

static String chipIdStr() {
    uint64_t chipid = ESP.getEfuseMac();
    uint32_t id = (uint32_t)(chipid & 0xFFFFFFFF);
    char buf[9];
    snprintf(buf, sizeof(buf), "%08X", id);
    return String(buf);
}

// ============================================================================
// SENSOR FUNCTIONS
// ============================================================================

static int getSoilMoisture() {
    int moisture, sensor_analog;
    
    sensor_analog = analogRead(MOISTURE_SENSOR_PIN);
    moisture = (100 - ((sensor_analog / 4095.00) * 100));
    return moisture;
}

static float getTemperature() {
    float temp = dht.readTemperature();
    if (isnan(temp)) {
        Serial.println("Failed to read temperature from DHT22");
        return -999.0;
    }
    return temp;
}

static float getHumidity() {
    float hum = dht.readHumidity();
    if (isnan(hum)) {
        Serial.println("Failed to read humidity from DHT22");
        return -999.0;
    }
    return hum;
}

// ============================================================================
// PUMP CONTROL FUNCTIONS
// ============================================================================

static void startPumping(float moistureDelta) {
    if (isPumping) {
        Serial.println("Already pumping, ignoring new command");
        return;
    }
    
    baseMoisture = getSoilMoisture();
    targetMoistureIncrease = moistureDelta;
    pumpStartTime = millis();
    isPumping = true;
    
    // Turn on LED to indicate pumping
    digitalWrite(LED_BUILTIN_PIN, HIGH);
    
    Serial.printf("PUMP STARTED: Base moisture=%d%%, Target increase=%.1f%%\n", 
                  baseMoisture, targetMoistureIncrease);
}

static void stopPumping() {
    if (!isPumping) return;
    
    isPumping = false;
    targetMoistureIncrease = 0.0;
    
    // Turn off LED
    digitalWrite(LED_BUILTIN_PIN, LOW);
    
    int currentMoisture = getSoilMoisture();
    Serial.printf("PUMP STOPPED: Final moisture=%d%% (started at %d%%)\n", 
                  currentMoisture, baseMoisture);
}

static void updatePumpStatus() {
    if (!isPumping) return;
    
    int currentMoisture = getSoilMoisture();
    float moistureIncrease = (float)(currentMoisture - baseMoisture);
    unsigned long pumpDuration = millis() - pumpStartTime;
    
    // Check if target moisture increase reached
    if (moistureIncrease >= targetMoistureIncrease) {
        Serial.printf("Target moisture reached! Increase: %.1f%% (target: %.1f%%)\n", 
                      moistureIncrease, targetMoistureIncrease);
        stopPumping();
        return;
    }
    
    // Safety timeout - prevent pumping forever
    if (pumpDuration >= MAX_PUMP_DURATION) {
        Serial.println("SAFETY: Max pump duration reached, stopping pump");
        stopPumping();
        return;
    }
    
    // Log progress every 2 seconds
    static unsigned long lastLog = 0;
    if (millis() - lastLog >= 2000) {
        lastLog = millis();
        Serial.printf("Pumping... Current moisture=%d%%, Increase=%.1f%% (target: %.1f%%), Duration=%lus\n",
                      currentMoisture, moistureIncrease, targetMoistureIncrease, pumpDuration / 1000);
    }
}

// ============================================================================
// NETWORK FUNCTIONS
// ============================================================================

void connectToWifi(const String &ssid, const String &pass, uint32_t timeout_ms) {
    Serial.printf("Connecting to WiFi SSID: '%s'\n", ssid.c_str());
    WiFi.begin(ssid.c_str(), pass.c_str());
    
    unsigned long start = millis();
    while (WiFi.status() != WL_CONNECTED && (millis() - start) < timeout_ms) {
        delay(200);
        Serial.print('.');
    }
    Serial.println();
    
    if (WiFi.status() == WL_CONNECTED) {
        Serial.printf("WiFi connected! IP: %s\n", WiFi.localIP().toString().c_str());
    } else {
        Serial.println("WiFi connection failed or timed out");
    }
}

bool testMqttConnection(const String &mqttHost) {
    mqttClient.setServer(mqttHost.c_str(), MQTT_PORT);
    
    Serial.printf("Testing MQTT connection to %s:%u\n", mqttHost.c_str(), MQTT_PORT);
    
    unsigned long start = millis();
    while (!mqttClient.connected() && (millis() - start) < 10000) {
        if (mqttClient.connect(chipId.c_str())) {
            Serial.println("MQTT test connection successful!");
            mqttClient.disconnect();
            return true;
        }
        Serial.print(".");
        delay(500);
    }
    
    Serial.println();
    Serial.println("MQTT test connection failed");
    return false;
}

static bool connectToHub() {
    preferences.begin(PREF_NAMESPACE, true);
    String mqttHost = preferences.getString("mqttHost", "");
    preferences.end();
    
    if (mqttHost.length() == 0) {
        Serial.println("ERROR: MQTT Host not configured");
        return false;
    }
    
    mqttClient.setServer(mqttHost.c_str(), MQTT_PORT);
    mqttClient.setCallback(receiveMqttData);
    
    Serial.printf("Connecting to MQTT Hub at %s:%u\n", mqttHost.c_str(), MQTT_PORT);
    Serial.printf("Client ID: %s (Device ID: %s)\n", chipId.c_str(), deviceId.c_str());
    
    unsigned long start = millis();
    while (!mqttClient.connected() && (millis() - start) < 10000) {
        if (mqttClient.connect(chipId.c_str())) {
            Serial.println("MQTT connected to Hub!");
            
            // Subscribe to command topic using actual device ID
            String commandTopic = "actuators/" + deviceId + "/set";
            if (mqttClient.subscribe(commandTopic.c_str())) {
                Serial.printf("Subscribed to: %s\n", commandTopic.c_str());
            } else {
                Serial.printf("Failed to subscribe to: %s\n", commandTopic.c_str());
            }
            
            return true;
        }
        Serial.print(".");
        delay(500);
    }
    
    Serial.println();
    Serial.println("MQTT connection to Hub failed");
    return false;
}

// ============================================================================
// MQTT DATA FUNCTIONS
// ============================================================================

static void sendMqttData(const String &topic, const String &payload) {
    if (!mqttClient.connected()) {
        Serial.println("MQTT not connected, cannot send data");
        return;
    }
    
    bool success = mqttClient.publish(topic.c_str(), payload.c_str());
    if (success) {
        Serial.printf("Published to '%s': %s\n", topic.c_str(), payload.c_str());
    } else {
        Serial.printf("Failed to publish to '%s'\n", topic.c_str());
    }
}

static void receiveMqttData(char* topic, byte* payload, unsigned int length) {
    Serial.print("Message received on topic: ");
    Serial.println(topic);
    
    String message = "";
    for (unsigned int i = 0; i < length; i++) {
        message += (char)payload[i];
    }
    
    Serial.print("Payload: ");
    Serial.println(message);
    
    // Parse actuator command JSON: {"metric":"moisture", "delta":1.0}
    StaticJsonDocument<256> doc;
    DeserializationError err = deserializeJson(doc, message);
    
    if (err) {
        Serial.print("JSON parse error: ");
        Serial.println(err.c_str());
        return;
    }
    
    const char* metric = doc["metric"] | "";
    float delta = doc["delta"] | 0.0;
    
    Serial.printf("Command: metric=%s, delta=%.1f\n", metric, delta);
    
    // Handle moisture pump command
    if (strcmp(metric, "moisture") == 0 && delta > 0) {
        Serial.printf("Starting pump to increase moisture by %.1f%%\n", delta);
        startPumping(delta);
    } else if (strcmp(metric, "moisture") == 0 && delta <= 0) {
        Serial.println("Stopping pump (delta <= 0)");
        stopPumping();
    } else {
        Serial.printf("Unknown metric or invalid delta: %s\n", metric);
    }
}

// ============================================================================
// TELEMETRY FUNCTIONS
// ============================================================================

static void sendMoistureData(int moisture) {
    StaticJsonDocument<256> doc;
    doc["device_id"] = deviceId;
    doc["data_type"] = "moisture";
    doc["data"] = moisture;
    doc["data_unit"] = "%";
    
    String payload;
    serializeJson(doc, payload);
    
    sendMqttData(MQTT_TOPIC_TELEMETRY, payload);
}

static void sendTemperatureData(float temperature) {
    StaticJsonDocument<256> doc;
    doc["device_id"] = deviceId;
    doc["data_type"] = "temperature";
    doc["data"] = round(temperature * 10.0) / 10.0;  // Round to 1 decimal place
    doc["data_unit"] = "C";
    
    String payload;
    serializeJson(doc, payload);
    
    sendMqttData(MQTT_TOPIC_TELEMETRY, payload);
}

static void sendHumidityData(int humidity) {
    StaticJsonDocument<256> doc;
    doc["device_id"] = deviceId;
    doc["data_type"] = "humidity";
    doc["data"] = humidity;
    doc["data_unit"] = "%";
    
    String payload;
    serializeJson(doc, payload);
    
    sendMqttData(MQTT_TOPIC_TELEMETRY, payload);
}

// ============================================================================
// PUBLIC API
// ============================================================================

void configured_setup() {
    chipId = "PD-" + chipIdStr();
    
    // Initialize DHT22 sensor
    dht.begin();
    
    Serial.println("Device is configured");
    
    // Read stored configuration
    preferences.begin(PREF_NAMESPACE, true);
    String ssid = preferences.getString("ssid", "");
    String pass = preferences.getString("pass", "");
    String mqttHost = preferences.getString("mqttHost", "");
    deviceId = preferences.getString("deviceId", "");
    preferences.end();
    
    Serial.println("Stored configuration:");
    Serial.printf("  Device ID: %s\n", deviceId.c_str());
    Serial.printf("  WiFi SSID: %s\n", ssid.c_str());
    Serial.printf("  MQTT Host: %s:%u\n\n", mqttHost.c_str(), MQTT_PORT);
    
    // Connect to WiFi
    connectToWifi(ssid, pass);
    
    if (WiFi.status() == WL_CONNECTED) {
        // Connect to MQTT Hub
        if (connectToHub()) {
            Serial.println("\nSystem ready and connected!\n");
        } else {
            Serial.println("\nMQTT connection failed\n");
        }
    } else {
        Serial.println("\nWiFi connection failed\n");
    }
}

void configured_loop() {
    // Update pump status (check if target moisture reached)
    updatePumpStatus();
    
    // Ensure MQTT stays connected
    if (!mqttClient.connected()) {
        Serial.println("MQTT disconnected, attempting reconnect...");
        if (WiFi.status() != WL_CONNECTED) {
            preferences.begin(PREF_NAMESPACE, true);
            String ssid = preferences.getString("ssid", "");
            String pass = preferences.getString("pass", "");
            preferences.end();
            connectToWifi(ssid, pass);
            
            if (WiFi.status() != WL_CONNECTED) {
                delay(100);
                return;  // WiFi reconnection failed, skip this cycle
            }
        }
        
        if (!connectToHub()) {
            delay(100);
            return;  // MQTT reconnection failed, skip this cycle
        }
    }
    
    // Process MQTT messages
    mqttClient.loop();
    
    // Publish telemetry data periodically
    unsigned long now = millis();
    if (now - lastPublish >= PUBLISH_INTERVAL) {
        lastPublish = now;
        
        // Read soil moisture sensor
        int soilMoisturePercent = getSoilMoisture();
        
        // Read DHT22 sensor
        float temperature = getTemperature();
        float humidity = getHumidity();
        
        Serial.printf("Soil Moisture: %d%%, Temperature: %.1f°C, Humidity: %.1f%%\n", 
                      soilMoisturePercent, temperature, humidity);
        
        sendMoistureData(soilMoisturePercent);
        sendTemperatureData(temperature);
        sendHumidityData(static_cast<int>(humidity));
    }
    
    delay(100);
}
