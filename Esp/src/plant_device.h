// Plant Device - Configured state handling
// Handles sensors, MQTT, WiFi, and pump control
#ifndef PLANT_DEVICE_H
#define PLANT_DEVICE_H

#include <Arduino.h>

// Initialize configured device (WiFi, MQTT, sensors)
void configured_setup();

// Main loop for configured device
void configured_loop();

// Network functions (also used by BLE config during setup)
void connectToWifi(const String &ssid, const String &pass, uint32_t timeout_ms = 2000);
bool testMqttConnection(const String &mqttHost);

#endif // PLANT_DEVICE_H
