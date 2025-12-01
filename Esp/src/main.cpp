// PlantProject main firmware for ESP32
#include <Arduino.h>
#include <WiFi.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLEAdvertising.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include <PubSubClient.h>
#include <DHT.h>


// ============================================================================
// CONFIGURATION
// ============================================================================

// Config namespace in NVS
static const char *PREF_NAMESPACE = "plantdev";

// Pin definitions
static const int RESET_SWITCH_PIN = 32;  // with internal pull-down
static const int LED_BUILTIN_PIN = 2;     // LED indicates pump status (ON = pumping)
static const int MOISTURE_SENSOR_PIN = 33;  // ADC1_CH5 - safe to use with WiFi
static const int DHT_PIN = 19;  // DHT22 data pin

// DHT22 sensor
#define DHTTYPE DHT22
DHT dht(DHT_PIN, DHTTYPE);

// Hard-coded Hub configuration (known before first startup)
static const uint16_t MQTT_PORT = 1883;
static const char* MQTT_TOPIC_TELEMETRY = "telemetry";
// Command topic will be constructed dynamically: actuators/{deviceId}/set

// Device globals
Preferences preferences;
String chipId;      // Hardware chip ID (used for BLE advertising)
String deviceId;    // Custom device ID (received via BLE config, used in MQTT)

// BLE receive buffer
static String bleConfigData = "";
static volatile bool haveBleData = false;

// BLE Server
static BLEServer* pBleServer = nullptr;
static BLECharacteristic* pBleCharacteristic = nullptr;

class MyCharacteristicCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) override {
        std::string val = pCharacteristic->getValue();
        if (!val.empty()) {
            bleConfigData = String((const char*)val.data(), val.length());
            haveBleData = true;
        }
    }
};

// MQTT
WiFiClient espClient;
PubSubClient mqttClient(espClient);
unsigned long lastPublish = 0;
const unsigned long PUBLISH_INTERVAL = 10UL * 1000UL; // 10s

// Pump control state
bool isPumping = false;
float targetMoistureIncrease = 0.0;  // Target moisture increase (delta)
int baseMoisture = 0;                 // Moisture reading when pumping started
unsigned long pumpStartTime = 0;      // When pumping started
static const unsigned long MAX_PUMP_DURATION = 30000;  // Safety: max 30 seconds pumping

// ============================================================================
// FUNCTION DECLARATIONS
// ============================================================================

String chipIdStr();
bool isConfigured();
bool saveConfig(const String &ssid, const String &pass, const String &mqttHost, const String &devId);
void clearConfig();
void receiveConfigFromBLE();
void connectToWifi(const String &ssid, const String &pass, uint32_t timeout_ms = 20000);
bool connectToHub();
void sendMqttData(const String &topic, const String &payload);
void receiveMqttData(char* topic, byte* payload, unsigned int length);
void startBLEConfigPortal();
void checkResetSwitch();
void updatePumpStatus();
void startPumping(float moistureDelta);
void stopPumping();
int getSoilMoisture();
float getTemperature();
float getHumidity();
void sendMoistureData(int moisture);
void sendTemperatureData(float temperature);
void sendHumidityData(float humidity);

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

String chipIdStr() {
    uint64_t chipid = ESP.getEfuseMac();
    uint32_t id = (uint32_t)(chipid & 0xFFFFFFFF);
    char buf[9];
    snprintf(buf, sizeof(buf), "%08X", id);
    return String(buf);
}

// ============================================================================
// CONFIGURATION FUNCTIONS
// ============================================================================

bool isConfigured() {
    preferences.begin(PREF_NAMESPACE, false);
    bool cfg = preferences.getBool("configured", false);
    preferences.end();
    return cfg;
}

bool saveConfig(const String &ssid, const String &pass, const String &mqttHost, const String &devId) {
    preferences.begin(PREF_NAMESPACE, false);
    preferences.putString("ssid", ssid);
    preferences.putString("pass", pass);
    preferences.putString("mqttHost", mqttHost);
    preferences.putString("deviceId", devId);
    preferences.putBool("configured", true);
    preferences.end();
    Serial.println("Configuration saved to NVS");
    return true;
}

void clearConfig() {
    preferences.begin(PREF_NAMESPACE, false);
    preferences.clear();
    preferences.end();
    Serial.println("Configuration cleared from NVS");
}

// ============================================================================
// RESET SWITCH AND LED FUNCTIONS
// ============================================================================

void checkResetSwitch() {
    if (digitalRead(RESET_SWITCH_PIN) == HIGH) {
        Serial.println("Reset switch activated! Clearing configuration...");
        clearConfig();
        Serial.println("Rebooting...");
        digitalWrite(LED_BUILTIN_PIN, LOW);
        delay(1000);
        ESP.restart();
    }
}

void startPumping(float moistureDelta) {
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

void stopPumping() {
    if (!isPumping) return;
    
    isPumping = false;
    targetMoistureIncrease = 0.0;
    
    // Turn off LED
    digitalWrite(LED_BUILTIN_PIN, LOW);
    
    int currentMoisture = getSoilMoisture();
    Serial.printf("PUMP STOPPED: Final moisture=%d%% (started at %d%%)\n", 
                  currentMoisture, baseMoisture);
}

void updatePumpStatus() {
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

int getSoilMoisture() {
    int moisture,sensor_analog;
    
    sensor_analog = analogRead(MOISTURE_SENSOR_PIN);
    moisture = ( 100 - ( (sensor_analog/4095.00) * 100 ) );
    return moisture;
}

float getTemperature() {
    float temp = dht.readTemperature();
    if (isnan(temp)) {
        Serial.println("Failed to read temperature from DHT22");
        return -999.0;
    }
    return temp;
}

float getHumidity() {
    float hum = dht.readHumidity();
    if (isnan(hum)) {
        Serial.println("Failed to read humidity from DHT22");
        return -999.0;
    }
    return hum;
}

// ============================================================================
// BLE CONFIGURATION PORTAL
// ============================================================================

void startBLEConfigPortal() {
    // Create a more human-readable BLE name using chip ID
    String bleName = "PlantDevice-" + chipId.substring(3);  // e.g., "PlantDevice-1234ABCD"
    BLEDevice::init(bleName.c_str());
    pBleServer = BLEDevice::createServer();
    
    BLEService *pService = pBleServer->createService("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
    pBleCharacteristic = pService->createCharacteristic(
        "beb5483e-36e1-4688-b7f5-ea07361b26a8",
        BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR | BLECharacteristic::PROPERTY_READ
    );
    pBleCharacteristic->setCallbacks(new MyCharacteristicCallbacks());
    pService->start();

    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
    pAdvertising->setScanResponse(false);
    pAdvertising->setMinPreferred(0x06);
    pAdvertising->setMinPreferred(0x12);
    pAdvertising->start();
    
    Serial.printf("BLE Config Portal started. BLE name: %s\n", bleName.c_str());
    Serial.println("Waiting for configuration via BLE...");
    Serial.println("Expected JSON: {\"ssid\":\"YourWiFi\",\"pass\":\"YourPassword\",\"mqttHost\":\"192.168.1.100\",\"deviceId\":\"my-device-001\"}");
}

void receiveConfigFromBLE() {
    if (!haveBleData) {
        return;
    }
    
    Serial.println("=== BLE Configuration Received ===");
    Serial.print("Raw data: ");
    Serial.println(bleConfigData);
    
    StaticJsonDocument<512> doc;
    DeserializationError err = deserializeJson(doc, bleConfigData);
    
    if (err) {
        Serial.print("JSON parse error: ");
        Serial.println(err.c_str());
        haveBleData = false;
        return;
    }
    
    const char* ssid = doc["ssid"] | "";
    const char* pass = doc["pass"] | "";
    const char* mqttHost = doc["mqttHost"] | "";
    const char* devId = doc["deviceId"] | "";
    
    if (strlen(ssid) == 0 || strlen(mqttHost) == 0 || strlen(devId) == 0) {
        Serial.println("ERROR: ssid, mqttHost, and deviceId are required!");
        haveBleData = false;
        return;
    }
    
    Serial.printf("Parsed - Device ID: %s, SSID: %s, MQTT Host: %s\n", devId, ssid, mqttHost);
    
    // Try to connect to WiFi with received credentials
    connectToWifi(String(ssid), String(pass));
    
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("WiFi connection failed. Configuration NOT saved.");
        haveBleData = false;
        return;
    }
    
    // Try to connect to MQTT Hub
    preferences.begin(PREF_NAMESPACE, false);
    preferences.putString("mqttHost", String(mqttHost));
    preferences.end();
    
    if (!connectToHub()) {
        Serial.println("MQTT connection failed. Configuration NOT saved.");
        haveBleData = false;
        return;
    }
    
    // Success! Save configuration
    deviceId = String(devId);  // Set the global deviceId
    saveConfig(String(ssid), String(pass), String(mqttHost), deviceId);
    Serial.println("=== Configuration Complete! Device will restart... ===");
    digitalWrite(LED_BUILTIN_PIN, LOW);
    delay(2000);
    ESP.restart();
    
    haveBleData = false;
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

bool connectToHub() {
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
        if (mqttClient.connect(chipId.c_str())) {  // Use chipId as MQTT client ID (unique per hardware)
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

void sendMqttData(const String &topic, const String &payload) {
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

void receiveMqttData(char* topic, byte* payload, unsigned int length) {
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
// ARDUINO SETUP & LOOP
// ============================================================================

void setup() {
    Serial.begin(115200);
    delay(2000);  // 2 second startup delay
    
    // Initialize pins
    pinMode(RESET_SWITCH_PIN, INPUT_PULLDOWN);  // Use internal pull-down resistor
    pinMode(LED_BUILTIN_PIN, OUTPUT);           // LED indicates pump status
    pinMode(MOISTURE_SENSOR_PIN, INPUT);        // ADC input for soil moisture sensor
    digitalWrite(LED_BUILTIN_PIN, LOW);
    
    // Initialize DHT22 sensor
    dht.begin();
    
    Serial.println("\n\n====================================");
    Serial.println("  Plant IoT Device - Local Hub");
    Serial.println("====================================");
    
    chipId = "PD-" + chipIdStr();
    Serial.printf("Chip ID: %s\n\n", chipId.c_str());
    
    if (!isConfigured()) {
        Serial.println("Device not configured");
        startBLEConfigPortal();
    } else {
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
}

void loop() {
    checkResetSwitch();
    
    // If device is not configured, handle BLE configuration
    if (!isConfigured()) {
        receiveConfigFromBLE();
        delay(100);
        return;
    }
    
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
        }
        
        if (WiFi.status() == WL_CONNECTED) {
            connectToHub();
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
        sendHumidityData(humidity);
    }
    
    delay(100);
}

void sendMoistureData(int moisture) {
    StaticJsonDocument<256> doc;
    doc["device_id"] = deviceId;
    doc["data_type"] = "moisture";
    doc["data"] = moisture;
    doc["data_unit"] = "%";
    
    String payload;
    serializeJson(doc, payload);
    
    sendMqttData(MQTT_TOPIC_TELEMETRY, payload);
}

void sendTemperatureData(float temperature) {
    StaticJsonDocument<256> doc;
    doc["device_id"] = deviceId;
    doc["data_type"] = "temperature";
    doc["data"] = temperature;
    doc["data_unit"] = "C";
    
    String payload;
    serializeJson(doc, payload);
    
    sendMqttData(MQTT_TOPIC_TELEMETRY, payload);
}

void sendHumidityData(float humidity) {
    StaticJsonDocument<256> doc;
    doc["device_id"] = deviceId;
    doc["data_type"] = "humidity";
    doc["data"] = humidity;
    doc["data_unit"] = "%";
    
    String payload;
    serializeJson(doc, payload);
    
    sendMqttData(MQTT_TOPIC_TELEMETRY, payload);
}