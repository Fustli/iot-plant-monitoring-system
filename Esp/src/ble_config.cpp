// BLE Configuration Portal implementation
#include "ble_config.h"
#include "plant_device.h"
#include <WiFi.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLEAdvertising.h>
#include <Preferences.h>
#include <ArduinoJson.h>

// ============================================================================
// CONFIGURATION
// ============================================================================

static const char *PREF_NAMESPACE = "plantdev";
static const int LED_BUILTIN_PIN = 2;

// ============================================================================
// BLE GLOBALS
// ============================================================================

static Preferences preferences;
static String chipId;
static String deviceId;

// BLE receive buffer
static String bleConfigData = "";
static volatile bool haveBleData = false;

// BLE Server
static BLEServer* pBleServer = nullptr;
static BLECharacteristic* pBleCharacteristic = nullptr;

// LED blinking for unconfigured state
static unsigned long lastLedToggle = 0;
static const unsigned long LED_BLINK_INTERVAL = 500;
static bool ledState = false;

// ============================================================================
// BLE CALLBACKS
// ============================================================================

class MyCharacteristicCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) override {
        std::string val = pCharacteristic->getValue();
        if (!val.empty()) {
            bleConfigData = String((const char*)val.data(), val.length());
            haveBleData = true;
        }
    }
};

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
// CONFIGURATION FUNCTIONS
// ============================================================================

bool isConfigured() {
    preferences.begin(PREF_NAMESPACE, false);
    bool cfg = preferences.getBool("configured", false);
    preferences.end();
    return cfg;
}

static bool saveConfig(const String &ssid, const String &pass, const String &mqttHost, const String &devId) {
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
// BLE CONFIGURATION PORTAL
// ============================================================================

static void startBLEConfigPortal() {
    String bleName = "PlantDevice-" + chipId.substring(3);
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

static void receiveConfigFromBLE() {
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
    if (!testMqttConnection(String(mqttHost))) {
        Serial.println("MQTT connection failed. Configuration NOT saved.");
        haveBleData = false;
        return;
    }
    
    // Success! Save configuration
    deviceId = String(devId);
    saveConfig(String(ssid), String(pass), String(mqttHost), deviceId);
    Serial.println("=== Configuration Complete! Device will restart... ===");
    digitalWrite(LED_BUILTIN_PIN, LOW);
    delay(2000);
    ESP.restart();
    
    haveBleData = false;
}

// ============================================================================
// PUBLIC API
// ============================================================================

void not_configured_setup() {
    chipId = "PD-" + chipIdStr();
    Serial.println("Device not configured");
    startBLEConfigPortal();
}

void not_configured_loop() {
    // Blink LED at 500ms interval to indicate unconfigured state
    unsigned long now = millis();
    if (now - lastLedToggle >= LED_BLINK_INTERVAL) {
        lastLedToggle = now;
        ledState = !ledState;
        digitalWrite(LED_BUILTIN_PIN, ledState ? HIGH : LOW);
    }
    
    receiveConfigFromBLE();
    delay(100);
}
