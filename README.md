# NavBand

**iOS-native wearable navigation for people with combined vision and hearing loss (e.g., Usher Syndrome).**

NavBand is an accessibility-focused navigation system that converts turn guidance into **haptic feedback** instead of visual or audio cues. The iOS app embeds a React navigation interface and bridges turn commands over BLE to an ESP32-powered wearable that vibrates for directional guidance.

---

## Why NavBand?

Traditional navigation apps depend on screens and spoken instructions. NavBand is designed for users who may not be able to rely on either.

- **No audio dependency**: guidance is delivered through vibration.
- **No visual dependency**: core guidance can be followed without reading the display.
- **Accessibility-first interaction model**: built to support independent navigation.

---

## System Architecture

NavBand has three cooperating layers:

1. **React navigation web app** (embedded in iOS)
   - Live location tracking
   - Directions + turn extraction
   - Destination search (Google Places Autocomplete)
   - Sends turn commands (`LEFT`, `RIGHT`, `STRAIGHT`) to native iOS bridge

2. **Native iOS shell (Swift)**
   - `WKWebView` hosts the web app
   - `WKScriptMessageHandler` receives JS BLE commands
   - `CoreBluetooth` scans, connects, discovers characteristics, and writes BLE data to hardware
   - Sends BLE connection state back to the web app via `evaluateJavaScript`

3. **Wearable hardware (ESP32 + vibration motor)**
   - BLE peripheral receives command strings
   - Relay/motor controller triggers haptic patterns for each direction

---

## Repository Overview

This repo currently contains the **iOS native wrapper + embedded built web assets**:

- `NavBand/`
  - Swift application code (`AppDelegate`, `ViewController`, etc.)
  - BLE bridge and WebView integration
- `build/`
  - Production web bundle loaded by the iOS app (`index.html`, CSS/JS assets)
- `NavBand.xcodeproj/`
  - Xcode project configuration
- `NavBandTests/`, `NavBandUITests/`
  - Test targets scaffolding

---

## Core Native Flow

At runtime, the app:

1. Launches a `WKWebView` and loads `build/index.html` from the app bundle.
2. Registers a JavaScript message handler named `ble`.
3. Initializes `CBCentralManager` and scans for the NavBand BLE service UUID.
4. Connects to the discovered peripheral and locates the command characteristic.
5. Receives JS messages and writes UTF-8 command payloads to BLE.
6. Pushes BLE state updates back to JavaScript (`Initializing`, `Scanning`, `Connecting`, `Connected`, `Ready`, etc.).

---

## BLE Protocol

Current command payloads sent to the wearable:

- `LEFT`
- `RIGHT`
- `STRAIGHT`

These are written to a specific BLE characteristic after service/characteristic discovery.

---

## Permissions (iOS)

The app declares:

- Bluetooth usage description
- Location (When In Use + Always/When In Use)

These are required for BLE communication and navigation tracking.

---

## Running Locally (iOS)

### Prerequisites

- Xcode 15+
- iOS device (recommended for BLE testing)
- Apple Developer signing setup (for on-device run)

### Steps

1. Open `NavBand.xcodeproj` in Xcode.
2. Select a signing team for the app target.
3. Ensure the `build/` folder is included in Copy Bundle Resources.
4. Build and run on an iPhone.
5. Power on your ESP32 NavBand peripheral and verify BLE connection logs.

> Note: BLE behavior is best validated on physical hardware. Simulator support for real BLE workflows is limited.

---

## Accessibility Notes

NavBand’s UX is intentionally oriented toward low-vision usability in the web layer (high contrast, larger controls) while the primary feedback path is haptic. This allows the system to remain useful even when visual/audio channels are limited.

---

## Deployment Model

- Web UI can be maintained and built separately as a React project.
- The resulting static build is bundled into this iOS app.
- iOS distribution can be done through TestFlight/internal sharing after code signing.

---

## Roadmap

Potential improvements:

- Native Google Navigation SDK integration for richer turn handling/rerouting
- More expressive haptic profiles (rhythm/intensity per event type)
- Smaller wearable hardware form factor
- Better battery optimization on the wearable
- Offline route caching for low-connectivity environments
- Android companion implementation

---

## Status

This project demonstrates a working hybrid architecture (Web UI + Native BLE bridge + wearable actuator) and serves as a practical foundation for assistive wearable navigation.

