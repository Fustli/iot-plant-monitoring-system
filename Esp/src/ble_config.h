// BLE Configuration Portal for unconfigured devices
#ifndef BLE_CONFIG_H
#define BLE_CONFIG_H

#include <Arduino.h>

// Initialize BLE configuration portal
void not_configured_setup();

// Handle BLE configuration loop (call repeatedly)
// Returns true if configuration was successful and device should restart
void not_configured_loop();

// Check if device is configured
bool isConfigured();

// Clear device configuration
void clearConfig();

#endif // BLE_CONFIG_H
