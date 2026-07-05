# Technical & Architectural Specification Report
**Project Name:** Digital Twin Monitor (`digital_twin_monitor`)  
**Product Concept:** Digital Twin–Based Mobile Gaming Behavior Monitoring System Client Application  
**Target Platform:** Android (via Flutter & Kotlin)

---

## 1. Project Overview
The **Digital Twin Monitor** is a hybrid Flutter and native Android mobile application designed to monitor, catalog, and synchronize real-time child device gameplay telemetry. Operating as a background foreground service, the app tracks when specific games are launched, active, or closed. It caches sessions locally in an SQLite database, filters out transient interactions via a debounce mechanism, and synchronizes the gameplay statistics with a remote digital twin dashboard backend server.

---

## 2. Technology Stack

### Frontend / Presentation Layer
- **Framework:** Flutter & Dart (SDK Version: `^3.10.1`)
- **Theme and UI:** Material 3 (Material Design implementation utilizing customized typography, premium colors, interactive animations, and responsive dialog boxes)

### Database Layer
- **Local SQLite Engine:** Managed via [sqflite](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/database.dart) (v2.3.0) in Dart, and raw Android SQLite helper APIs inside native Kotlin (`GameMonitorService.kt` / `openOrCreateDatabase`).
- **Data Persistence:** Offline events are written to a localized SQLite file (`gaming_monitor.db`) on Android's internal application storage.

### Service Controllers & API Layer
- **Networking Library:** `http` (v1.2.0) inside Dart.
- **Backend API Integration:** Custom REST API endpoints running on Render (`https://gaming-twin-backend.onrender.com`), secured with an API key authorization header (`X-API-KEY: secret`).

### Native Bindings & System APIs
- **Native Language:** Kotlin (v2.2.20) for Android extensions.
- **Android System SDKs:**
  - `UsageStatsManager` for application execution tracking.
  - `AppOpsManager` to verify system usage permission settings.
  - `NotificationManagerCompat` and channels for foreground notifications and alerts.
  - `AlarmManager` for service keep-alive scheduling.
- **Native Platform Channels:**
  - `installed_apps`: Queries, caches, and overrides app categorization metadata.
  - `game_detection`: Configures background monitoring loops and broadcasts state telemetry.
  - `usage_access`: Queries and navigates to the Android Usage Access Settings screen.
  - `notification_permission`: Queries and requests notification delivery permission.

### DevOps & Deployment
- **Gradle Compiler:** Gradle application plugins with target custom APK compilation renaming to `digitaltwinmonitor.apk`.

---

## 3. Detailed Feature Breakdown

### A. Parental Consent & Android Permissions Gatekeeping
To guarantee data privacy compliance and operational viability, the application implements an onboarding flow managed by [lib/screens/monitoring_gate.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/screens/monitoring_gate.dart):
1. **Usage Access Permission:** Prompts the user to grant permission to monitor app history via `AppOpsManager.OPSTR_GET_USAGE_STATS`. This check is controlled via `check_usage` and `open_settings` MethodCalls inside [lib/screens/consent_screen.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/screens/consent_screen.dart).
2. **System Notifications Permission:** Checked via [lib/screens/notification_gate_screen.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/screens/notification_gate_screen.dart) to deliver status alerts to the device tray.
3. **Battery Optimization Exemptions:** Triggers a prompt via [lib/screens/battery_gate_screen.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/screens/battery_gate_screen.dart) to bypass device stand-by restrictions, keeping the background tracking engine alive.

### B. Parental Security Control (Parent PIN)
A 4-digit security PIN is registered in [lib/screens/pin_create_screen.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/screens/pin_create_screen.dart) and verified in [lib/screens/pin_verify_screen.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/screens/pin_verify_screen.dart). This PIN is stored securely inside `SharedPreferences` and must be validated before:
- Halting the foreground service.
- Applying manual categorization overrides on installed apps.
- Logging out of the application.

### C. Application Scanning, Heuristics, & Classifications
The system lists all user-installed applications using [lib/services/installed_apps_service.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/services/installed_apps_service.dart) via the native `list_installed` method:
- **Heuristic Engine:** Automatically guesses if a package is a game by checking the Android O+ category flag (`ApplicationInfo.CATEGORY_GAME`) and examining package/label strings against keywords (`game`, `fight`, `battle`, `clash`, `racing`, `pubg`, `bgmi`, `minecraft`, `roblox`, etc.) inside the `detectGameHeuristic` function in [MainActivity.kt](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/android/app/src/main/kotlin/com/example/gaming_monitor_app/MainActivity.kt).
- **Manual Overrides:** Parents can manually force an application to be classified as a "Game" or "App" via the [lib/screens/installed_games_screen.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/screens/installed_games_screen.dart). This bypasses the default heuristics and caches the override choice in local preferences.

### D. Active Foreground Tracking & Debounce Logic
The native [GameMonitorService.kt](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/android/app/src/main/kotlin/com/example/gaming_monitor_app/GameMonitorService.kt) performs the polling logic:
- **Interval Polling:** Executes a background detection timer checking `UsageStatsManager` every 4 seconds.
- **Focus Shifts:** Detects package changes. If the user transitions from a game to a non-game app, a **Debounce Timer (8 seconds)** begins.
- **Debounce Logic:** Prevents false `STOP` events when the child quickly checks notifications, answers calls, or triggers system tasks. If the child returns to the game within 8 seconds, the stop timer is cancelled. If the child remains outside the game, a `STOP` telemetry payload is dispatched, recording the precise duration of play.

### E. Telemetry Actions & State Loop
Every monitored gaming session triggers three distinct lifecycle events:
- **`START`:** Fired the moment the user launches a flagged game application. Initial duration set to `0` minutes.
- **`HEARTBEAT`:** Periodically logs active gameplay status every 60 seconds. Each heartbeat records `1` minute of playtime.
- **`STOP`:** Fired once the game is closed (and remains closed past the 8-second debounce). Transmits the total elapsed session duration in minutes.

---

## 4. System Architecture & Coordination Flow

### Platform Channels Architecture

```
[Flutter UI / Services]
    │
    ├─► MethodChannel("usage_access") ──────────► MainActivity.kt (AppOpsManager check)
    ├─► MethodChannel("notification_permission")► MainActivity.kt (Notification check & trigger)
    ├─► MethodChannel("installed_apps") ────────► MainActivity.kt (Scan installed packages & icons)
    │
    └─► MethodChannel("game_detection") ────────► MainActivity.kt (Lifecycle, start_service, stop_service)
                                                      │
                                                      ▼
                                              [GameMonitorService] ◄──┐
                                                      │               │
                                                      ├─► Polls (4s) ─┘
                                                      │
                                                      ├─► Inserts telemetry inside SQL db
                                                      │
                                                      └─► InvokeMethod("log_event") (Dart Engine Cache)
```

### Preloaded Flutter Engine
To resolve black screen issues and facilitate communication from the background Kotlin thread when the Flutter UI is suspended, the app pre-initializes a Dart execution thread in [MainApplication.kt](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/android/app/src/main/kotlin/com/example/gaming_monitor_app/MainApplication.kt):
```kotlin
override fun onCreate() {
    super.onCreate()
    val engine = FlutterEngine(this)
    engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
    FlutterEngineCache.getInstance().put("preloaded_engine", engine)
}
```
This cached engine is referenced inside [GameMonitorService.kt](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/android/app/src/main/kotlin/com/example/gaming_monitor_app/GameMonitorService.kt) to directly execute the Dart callback MethodCall `log_event`, ensuring the Dart interface refreshes gameplay summaries in real-time.

### Synchronization & Offline Fail-Safe Protocols
Telemetry synchronization runs with dual-redundant logic:
1. **Direct HTTP Upload (Kotlin):** When [GameMonitorService.kt](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/android/app/src/main/kotlin/com/example/gaming_monitor_app/GameMonitorService.kt) processes a tracking event, it spawns a worker thread executing a network POST request to `/events`. If the server is offline (non-200/201 response), the record is saved to the native SQLite database with `synced = 0`.
2. **Direct HTTP Upload (Flutter Sync Loop):** [lib/services/sync_service.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/services/sync_service.dart) runs a recurring loop every 15 seconds. It queries the local database for pending entries (`synced = 0`), pushes them to `/events`, and updates their status to `synced = 1`.
3. **Triggered Backlog Uploads:** Successfully sending a live telemetry request triggers a helper function to sync the first 20 pending offline logs in the SQLite backlog.

---

## 5. Folder & Code Directory Map

### Dart Codebase (UI, Databases & Services)
- [lib/main.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/main.dart): Sets up routes, status styles, theme, and cold-start server warmups (`ServerWarmup`).
- [lib/database.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/database.dart): Manages the local `gaming_monitor.db` SQLite connection, schema definition (`game_events` table), insertions, and automatic cleanups (deleting synced entries older than 24 hours).
- **lib/screens/**:
  - [monitoring_gate.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/screens/monitoring_gate.dart): Decision routing gate verifying completed onboarding items (`consent_done`, `notif_done`, `battery_done`, `pin_set`, `parent_id`, `selected_child_id`).
  - [consent_screen.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/screens/consent_screen.dart): Gathers usage permissions and redirects to gate.
  - [login_screen.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/screens/login_screen.dart): Handles credential authorization, stores `auth_token`, and decodes child profiles.
  - [child_selection_screen.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/screens/child_selection_screen.dart): Displays child profiles and binds the target `selected_child_id` to the device.
  - [monitoring_screen.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/screens/monitoring_screen.dart): Control panel showing runtime tracking state, today's accumulated gameplay minutes, and actions to stop/start monitoring.
  - [installed_games_screen.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/screens/installed_games_screen.dart): Displays app lists, handles search filters, and processes category overrides.
  - [child_id_screen.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/screens/child_id_screen.dart): Displays details of the bound child profile and hosts the parent logout sequence.
- **lib/services/**:
  - [installed_apps_service.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/services/installed_apps_service.dart): Invokes package scanner and handles local cache layers in `SharedPreferences`.
  - [sync_service.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/services/sync_service.dart): Periodic loop to push offline logs.
  - [twin_service.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/services/twin_service.dart): Queries reports and twins from `/digital-twin` and `/reports` backend endpoints.
  - [service_controller.dart](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/lib/services/service_controller.dart): Coordinates starting and stopping the native service.

### Native Kotlin Android Module
- **android/app/src/main/kotlin/com/example/gaming_monitor_app/**:
  - [MainActivity.kt](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/android/app/src/main/kotlin/com/example/gaming_monitor_app/MainActivity.kt): Registers platform channels and handles background thread synchronization tasks for icon parsing and package scans.
  - [GameMonitorService.kt](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/android/app/src/main/kotlin/com/example/gaming_monitor_app/GameMonitorService.kt): Persistent background service running the core polling loop and handling telemetry uploads.
  - [BootReceiver.kt](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/android/app/src/main/kotlin/com/example/gaming_monitor_app/BootReceiver.kt): Broadcast receiver that restarts the tracking service automatically on boot.
  - [MainApplication.kt](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/android/app/src/main/kotlin/com/example/gaming_monitor_app/MainApplication.kt): Standard Application class configuring the preloaded engine cache.
- [AndroidManifest.xml](file:///c:/Users/HP/Desktop/Programming/Game%20monitor/gaming_monitor_app/android/app/src/main/AndroidManifest.xml): Registers permissions (`QUERY_ALL_PACKAGES`, `FOREGROUND_SERVICE`, `PACKAGE_USAGE_STATS`, `RECEIVE_BOOT_COMPLETED`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`), services, and receivers.

---

## 6. External Integrations & Telemetry Payload Specs

### Parent Login
- **Endpoint:** `POST /parent/login`
- **Request Body:**
```json
{
  "username": "parent_email@test.com",
  "password": "parent_password"
}
```
- **Response Structure (Success):**
```json
{
  "success": true,
  "parent_id": "12345",
  "token": "auth_token_string",
  "children": [
    {
      "child_id": "child_abc",
      "name": "Alex"
    }
  ]
}
```

### Telemetry Event Submission
- **Endpoint:** `POST /events`
- **Headers:**
  - `Content-Type: application/json`
  - `X-API-KEY: secret`
- **Request Body:**
```json
{
  "user_id": "child_abc",
  "childdeviceid": "android_child_abc",
  "status": "START | HEARTBEAT | STOP",
  "package_name": "com.tencent.ig",
  "game_name": "PUBG Mobile",
  "duration": 0,          // minutes (0 for START, 1 for HEARTBEAT, total for STOP)
  "start_time": 1718228300000, // Unix millisecond timestamp
  "end_time": 1718228900000,
  "timestamp": 1718228900000
}
```

### Digital Twin Report Retrieval
- **Endpoint:** `GET /reports/$childId`
- **Headers:**
  - `X-API-KEY: secret`
- **Response Structure:**
```json
{
  "today_minutes": 45,
  "weekly_minutes": 310,
  "night_minutes": 15
}
```

---

## 7. How to Setup and Run

### Prerequisites
1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install) (matching `^3.10.1` constraints).
2. Install Android Studio, build tools, and set up an Android Emulator or physical test device (Android SDK API 21+).

### Step-by-Step Execution
1. Fetch dependencies:
   ```bash
   flutter pub get
   ```
2. Connect a test device and launch the app in debug mode:
   ```bash
   flutter run
   ```
3. To compile a release build:
   ```bash
   flutter build apk
   ```
   The compiled APK file will be located at:
   `build/app/outputs/flutter-apk/digitaltwinmonitor.apk`

---

## 8. Architectural Observations & Future Recommendations

- **Hardcoded Configuration Values:** Base URLs (`https://gaming-twin-backend.onrender.com`) and verification keys (`X-API-KEY: secret`) are duplicated across Dart services and native Kotlin code.
  - *Recommendation:* Consolidate values inside build flavors or inject them as compile-time arguments via `--dart-define` parameters.
- **Concurrent DB Modifications:** Both Dart (`sqflite`) and Kotlin (`openOrCreateDatabase`) write to `gaming_monitor.db` concurrently. This can lead to database locking or read errors on certain Android kernels.
  - *Recommendation:* Route all writes through a single layer. Instead of direct SQLite operations in Kotlin, send events exclusively through the MethodChannel `log_event` and let Dart handle the database operations, or write events to standard Android shared files and let Dart process them.
- **Background Threading:** Telemetry network posts in Kotlin spawn raw OS threads:
  ```kotlin
  Thread { ... }.start()
  ```
  - *Recommendation:* Migrate native background networking tasks to Android's `WorkManager` API to improve stability and resource management.
