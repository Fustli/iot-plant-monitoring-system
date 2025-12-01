// PlantProject main firmware for ESP32
// Main entry point - handles reset switch and delegates to appropriate module
#include <Arduino.h>
#include "ble_config.h"
#include "plant_device.h"

// ============================================================================
// PIN DEFINITIONS
// ============================================================================

static const int RESET_SWITCH_PIN = 32;  // with internal pull-down
static const int LED_BUILTIN_PIN = 2;    // LED indicates pump status (ON = pumping)
static const int MOISTURE_SENSOR_PIN = 33;  // ADC input for soil moisture sensor

// ============================================================================
// RESET SWITCH FUNCTION
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
    
    Serial.println("\n\n====================================");
    Serial.println("  Plant IoT Device - Local Hub");
    Serial.println("====================================\n");
    
    if (!isConfigured()) {
        not_configured_setup();
    } else {
        configured_setup();
    }
}

void loop() {
    checkResetSwitch();
    
    if (!isConfigured()) {
        not_configured_loop();
    } else {
        configured_loop();
    }
}