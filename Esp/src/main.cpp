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

// ============================================================================
// CONFIGURATION
// ============================================================================

// Config namespace in NVS
static const char *PREF_NAMESPACE = "plantdev";

// Hard-coded Hub configuration (known before first startup)
static const uint16_t MQTT_PORT = 1883;
static const char* MQTT_TOPIC_TELEMETRY = "home/sensors/telemetry";
static const char* MQTT_TOPIC_COMMANDS = "home/sensors/commands";

// Device globals
Preferences preferences;
String deviceId;

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

// ============================================================================
// FUNCTION DECLARATIONS
// ============================================================================

String chipIdStr();
bool isConfigured();
bool saveConfig(const String &ssid, const String &pass, const String &mqttHost);
void receiveConfigFromBLE();
void connectToWifi(const String &ssid, const String &pass, uint32_t timeout_ms = 20000);
bool connectToHub();
void sendMqttData(const String &topic, const String &payload);
void receiveMqttData(char* topic, byte* payload, unsigned int length);
void startBLEConfigPortal();

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

bool saveConfig(const String &ssid, const String &pass, const String &mqttHost) {
    preferences.begin(PREF_NAMESPACE, false);
    preferences.putString("ssid", ssid);
    preferences.putString("pass", pass);
    preferences.putString("mqttHost", mqttHost);
    preferences.putBool("configured", true);
    preferences.end();
    Serial.println("Configuration saved to NVS");
    return true;
}

// ============================================================================
// BLE CONFIGURATION PORTAL
// ============================================================================

void startBLEConfigPortal() {
    // Create a more human-readable BLE name
    String bleName = "PlantDevice-" + chipIdStr().substring(4); // e.g., "PlantDevice-C3D4"
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
    
    Serial.printf("BLE Config Portal started. Device name: %s\n", deviceId.c_str());
    Serial.println("Waiting for configuration via BLE...");
    Serial.println("Expected JSON: {\"ssid\":\"YourWiFi\",\"pass\":\"YourPassword\",\"mqttHost\":\"192.168.1.100\"}");
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
    
    if (strlen(ssid) == 0 || strlen(mqttHost) == 0) {
        Serial.println("ERROR: ssid and mqttHost are required!");
        haveBleData = false;
        return;
    }
    
    Serial.printf("Parsed - SSID: %s, MQTT Host: %s\n", ssid, mqttHost);
    
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
    saveConfig(String(ssid), String(pass), String(mqttHost));
    Serial.println("=== Configuration Complete! Device will restart... ===");
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
        Serial.printf("✓ WiFi connected! IP: %s\n", WiFi.localIP().toString().c_str());
    } else {
        Serial.println("✗ WiFi connection failed or timed out");
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
    Serial.printf("Client ID: %s\n", deviceId.c_str());
    
    unsigned long start = millis();
    while (!mqttClient.connected() && (millis() - start) < 10000) {
        if (mqttClient.connect(deviceId.c_str())) {
            Serial.println("✓ MQTT connected to Hub!");
            
            // Subscribe to command topic
            if (mqttClient.subscribe(MQTT_TOPIC_COMMANDS)) {
                Serial.printf("✓ Subscribed to: %s\n", MQTT_TOPIC_COMMANDS);
            }
            
            return true;
        }
        Serial.print(".");
        delay(500);
    }
    
    Serial.println();
    Serial.println("✗ MQTT connection to Hub failed");
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
        Serial.printf("✓ Published to '%s': %s\n", topic.c_str(), payload.c_str());
    } else {
        Serial.printf("✗ Failed to publish to '%s'\n", topic.c_str());
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
    
    // Parse and handle command (example)
    StaticJsonDocument<256> doc;
    DeserializationError err = deserializeJson(doc, message);
    
    if (!err) {
        const char* command = doc["command"] | "unknown";
        Serial.printf("Command received: %s\n", command);
        // Handle specific commands here
    }
}

// ============================================================================
// ARDUINO SETUP & LOOP
// ============================================================================

void setup() {
    Serial.begin(115200);
    delay(500);
    
    Serial.println("\n\n====================================");
    Serial.println("  Plant IoT Device - Local Hub");
    Serial.println("====================================");
    
    deviceId = "PD-" + chipIdStr();
    Serial.printf("Device ID: %s\n\n", deviceId.c_str());
    
    if (!isConfigured()) {
        Serial.println("⚠ Device not configured");
        startBLEConfigPortal();
    } else {
        Serial.println("✓ Device is configured");
        
        // Read stored configuration
        preferences.begin(PREF_NAMESPACE, true);
        String ssid = preferences.getString("ssid", "");
        String pass = preferences.getString("pass", "");
        String mqttHost = preferences.getString("mqttHost", "");
        preferences.end();
        
        Serial.println("Stored configuration:");
        Serial.printf("  WiFi SSID: %s\n", ssid.c_str());
        Serial.printf("  MQTT Host: %s:%u\n\n", mqttHost.c_str(), MQTT_PORT);
        
        // Connect to WiFi
        connectToWifi(ssid, pass);
        
        if (WiFi.status() == WL_CONNECTED) {
            // Connect to MQTT Hub
            if (connectToHub()) {
                Serial.println("\n✓ System ready and connected!\n");
            } else {
                Serial.println("\n✗ MQTT connection failed\n");
            }
        } else {
            Serial.println("\n✗ WiFi connection failed\n");
        }
    }
}

void loop() {
    // If device is not configured, handle BLE configuration
    if (!isConfigured()) {
        receiveConfigFromBLE();
        delay(100);
        return;
    }
    
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
        
        // Create dummy sensor data (replace with real sensor readings)
        int soilMoisture = random(200, 800);  // Simulated analog value
        float temperature = 20.0 + random(0, 100) / 10.0;  // 20-30°C
        float humidity = 40.0 + random(0, 300) / 10.0;     // 40-70%
        
        // Build JSON payload
        StaticJsonDocument<256> doc;
        doc["device_id"] = deviceId;
        doc["timestamp"] = now;
        doc["soil_moisture"] = soilMoisture;
        doc["temperature"] = temperature;
        doc["humidity"] = humidity;
        
        String payload;
        serializeJson(doc, payload);
        
        // Send to Hub
        sendMqttData(MQTT_TOPIC_TELEMETRY, payload);
    }
    
    delay(100);
}
