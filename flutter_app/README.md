# IoT Plant Monitoring System - Flutter Frontend

**Status:** Dummy/Demo Frontend (No Backend Connection)

## Overview

A beautiful, responsive Flutter mobile application for the IoT Plant Monitoring System. This is a demo/prototype frontend showcasing the UI/UX with mock data.

**Features:**
- 📱 Multi-screen navigation (Home, Plants, Devices, Alerts, Settings)
- 🪴 Plant monitoring dashboard
- 📊 Mock sensor data visualization
- ⚠️ Alert management interface
- 🔧 Device status display
- 👤 User profile management
- 🎨 Modern Material 3 design

## Project Structure

```
flutter_app/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── screens/                  # Full-screen pages
│   │   ├── home_screen.dart
│   │   ├── plants_screen.dart
│   │   ├── devices_screen.dart
│   │   ├── alerts_screen.dart
│   │   └── settings_screen.dart
│   ├── models/                   # Data models (mock data structures)
│   │   ├── user_model.dart
│   │   ├── plant_model.dart
│   │   ├── device_model.dart
│   │   ├── alert_model.dart
│   │   ├── sensor_model.dart
│   │   └── manufacturer_model.dart
│   ├── widgets/                  # Reusable UI components
│   │   ├── plant_card.dart
│   │   ├── device_card.dart
│   │   ├── alert_card.dart
│   │   ├── bottom_navigation.dart
│   │   ├── health_indicator.dart
│   │   └── sensor_chart.dart
│   ├── providers/                # State management (Provider package)
│   │   ├── user_provider.dart
│   │   ├── plant_provider.dart
│   │   ├── device_provider.dart
│   │   └── alert_provider.dart
│   ├── services/                 # Mock data services
│   │   ├── mock_data_service.dart
│   │   ├── mock_api_service.dart
│   │   └── storage_service.dart
│   ├── constants/                # App-wide constants
│   │   ├── app_colors.dart
│   │   ├── app_strings.dart
│   │   ├── app_sizes.dart
│   │   └── app_icons.dart
│   ├── utils/                    # Utility functions
│   │   ├── date_utils.dart
│   │   ├── format_utils.dart
│   │   └── validators.dart
│   └── providers.dart            # Central exports
├── test/                         # Unit & widget tests
├── assets/
│   ├── images/                   # App images
│   ├── icons/                    # SVG/PNG icons
│   └── fonts/                    # Custom fonts
├── pubspec.yaml                  # Dependencies
├── analysis_options.yaml         # Lint rules
├── .gitignore                    # Git ignore rules
└── README.md                     # This file
```

## Getting Started

### Prerequisites
- Flutter SDK (3.0+)
- Dart SDK (included with Flutter)
- Android Studio or Xcode (for emulation)

### Installation

1. **Navigate to flutter_app:**
   ```bash
   cd flutter_app
   ```

2. **Get dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

### Available Platforms
- ✅ Android
- ✅ iOS
- ✅ Web (with flutter web)

## Architecture

### Layered Architecture
```
UI Layer (Screens & Widgets)
         ↓
State Management (Provider)
         ↓
Business Logic (Services)
         ↓
Data Layer (Models & Mock Data)
```

### State Management
- **Provider Package:** Manages app state across screens
- **Providers:**
  - `UserProvider` - Current user info
  - `PlantProvider` - All user's plants
  - `DeviceProvider` - All registered devices
  - `AlertProvider` - Active/resolved alerts

### Mock Data
All data is currently mocked using `mock_data_service.dart`:
- User data
- Plant list with health status
- Device list with battery levels
- Mock sensor readings
- Alerts with timestamps

## Key Screens

### 🏠 Home Screen
- User greeting
- Quick stats (plants, devices, alerts)
- Recent alerts overview
- Quick action buttons

### 🪴 Plants Screen
- List of user's plants
- Plant health status card
- Assigned devices for each plant
- Add/edit/delete plant actions

### 🔧 Devices Screen
- All registered IoT devices
- Device status (online/offline)
- Battery level indicators
- Signal strength
- Device details modal

### ⚠️ Alerts Screen
- Active alerts list
- Alert severity badges
- Filter by status (active, acknowledged, resolved)
- Acknowledgment action

### ⚙️ Settings Screen
- User profile information
- App preferences
- About section
- Demo data reset button

## Widgets & Components

### Plant Card
Shows plant overview:
- Plant image/icon
- Plant name and species
- Health status indicator
- Last watered date

### Device Card
Shows device info:
- Device name
- Status indicator (online/offline)
- Battery level
- Signal strength (RSSI)

### Alert Card
Shows alert details:
- Alert message
- Severity badge (INFO, WARNING, CRITICAL)
- Status (ACTIVE, ACKNOWLEDGED, RESOLVED)
- Timestamp
- Acknowledgment button

### Health Indicator
Visual indicator for plant health:
- 🟢 Healthy
- 🟡 Warning
- 🔴 Critical

## Color Scheme

```dart
Primary: #2D6A4F (Green)
Secondary: #40916C (Light Green)
Error: #E63946 (Red)
Warning: #F1FAEE (Light Cream)
Neutral: #E8E8E8 (Light Gray)
```

## Dependencies

| Package | Purpose |
|---------|---------|
| `provider` | State management |
| `google_fonts` | Typography |
| `fl_chart` | Data visualization |
| `intl` | Date formatting |
| `shared_preferences` | Local storage |
| `http` | Network requests (future use) |

## Implementation Status

- ✅ Multi-screen navigation structure
- ✅ Mock data models aligned with backend
- ✅ Material 3 UI framework
- ✅ State management with Provider
- ✅ Reusable widget components
- ✅ Constants and theme configuration
- ✅ App structure ready for screen implementations

## Testing

Run tests:
```bash
flutter test
```

## Code Quality

Lint analysis:
```bash
flutter analyze
```

Format code:
```bash
dart format lib/
```

## Documentation

For backend database details, see:
- `../db/documents/DATABASE_DOCS_INDEX.md` - Backend database documentation

## Notes

This is a demonstration/prototype frontend with mock data and no backend connection.
