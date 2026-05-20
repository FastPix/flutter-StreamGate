

# 📹 StreamGate

### Record. Upload. Stream. Instantly.

A production-ready Flutter mobile application that enables users to record videos or pick them from their gallery, upload them to the [FastPix](https://fastpix.io) media platform, and instantly stream or share them via an HLS-powered player.


---

## 📖 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Tech Stack](#-tech-stack)
- [Architecture](#-architecture)
- [Project Structure](#-project-structure)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Configuration](#️-configuration)
- [Running the App](#-running-the-app)
- [Building for Production](#-building-for-production)
- [Platform Setup](#-platform-setup)
- [API Integration](#-api-integration)
- [App Flow](#-app-flow)
- [State Management](#-state-management)
- [Security Notes](#-security-notes)
- [Performance Considerations](#-performance-considerations)
- [Troubleshooting](#-troubleshooting)
- [Roadmap](#-roadmap)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🌟 Overview

StreamGate removes all friction from the video sharing workflow. Users open the app, record a clip or pick one from their library, and within seconds have a shareable streaming link — no third-party upload tools, no manual processing, no separate video host to configure. The entire pipeline (capture → upload → transcode → playback) is handled in one seamless experience powered by the FastPix media infrastructure.

**Target platforms:** Android (API 21+) · iOS (12+)

---

## ✨ Features

| Feature | Details |
|---|---|
| 📷 In-app Camera Recording | Live preview, one-tap start/stop, automatic navigation to upload after recording |
| 🎞️ Gallery Video Upload | Pick any video from the device library via the native picker |
| ⬆️ Direct FastPix Upload | Signed PUT session upload with real-time progress tracking |
| 🔄 Transcoding Polling | Automatic polling until the video is `Ready` on FastPix servers |
| 🎬 HLS Playback | Full-featured player with seek, fullscreen, mute and playback controls via Chewie |
| 🔗 Instant Sharing | One-tap native share sheet with a ready-to-use web player URL |
| 📋 Copy to Clipboard | Copy the stream or web player URL with a single tap |
| 🔁 Retry & Error Handling | Graceful error states with retry support at every stage |

---

## 🛠 Tech Stack

### Core

| Layer | Technology | Version |
|---|---|---|
| Language | Dart | ≥ 3.0.0 |
| UI Framework | Flutter (Material 3) | ≥ 3.0.0 |
| HTTP Client | Dio | ^5.3.2 |
| State Management | ChangeNotifier (MVVM) | SDK built-in |

### Device & Media

| Purpose | Package | Version |
|---|---|---|
| Camera access & recording | `camera` | ^0.10.0+1 |
| Gallery video picker | `image_picker` | ^1.2.2 |
| Video playback (HLS) | `video_player` | ^2.9.2 |
| Player UI controls | `chewie` | ^1.8.5 |
| Native share sheet | `share_plus` | ^10.0.0 |
| File system paths | `path_provider` | ^2.1.4 |
| Path utilities | `path` | ^1.8.3 |

### Infrastructure

| Purpose | Technology |
|---|---|
| Media upload & transcoding | [FastPix](https://fastpix.io) REST API |
| Video streaming | FastPix HLS (`stream.fastpix.io`) |
| Web player embedding | FastPix hosted player (`play.fastpix.io`) |
| Upload session engine | `fastpix_resumable_uploader` (git dep) |

---

## 🏗 Architecture

StreamGate follows a **feature-first MVVM** architecture. Each feature is a self-contained vertical slice with its own `data`, `domain`, and `presentation` layers. A shared `core` module provides cross-feature utilities.

```
┌─────────────────────────────────────────────────┐
│                   Presentation                  │
│         Screen (StatefulWidget / setState)      │
│              ↕  addListener / notifyListeners   │
│         ViewModel (ChangeNotifier)              │
└────────────────────┬────────────────────────────┘
                     │ calls
┌────────────────────▼────────────────────────────┐
│                 Data / Service                  │
│      FastPixUploadEngine  |  RecordService      │
│              ↕ HTTP (Dio)                       │
└────────────────────┬────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────┐
│              FastPix REST API                   │
│  Upload Session  |  Media Status  |  HLS Stream │
└─────────────────────────────────────────────────┘
```

**Key design decisions:**

- **No external state management library** — `ChangeNotifier` + `addListener` in screens keeps the dependency graph small and the code readable for teams of any size.
- **AppDI** is a hand-rolled singleton registry. Services are instantiated once at startup and injected manually. This keeps DI transparent without requiring code generation.
- **Feature isolation** — features import from `core/` but never from each other's `data/` layers. Cross-feature navigation happens via `Navigator.push` in presentation code only.

---

## 📁 Project Structure

```
streamgate_flutter/
│
├── android/                        # Android host project
├── ios/                            # iOS host project
├── assets/
│   └── icon/                       # App icon assets
│
├── lib/
│   ├── main.dart                   # Entry point — runApp(StreamGateApp)
│   ├── app.dart                    # Root MaterialApp, theme, initial route
│   │
│   ├── core/
│   │   ├── di/
│   │   │   └── app_di.dart         # Singleton registry (FastPixUploadService)
│   │   ├── network/
│   │   │   └── dio_client.dart     # Shared Dio instance with timeouts
│   │   └── utils/
│   │       ├── app_logger.dart     # Debug-only logger (kDebugMode guard)
│   │       └── constants.dart      # FastPix API base URLs and credentials
│   │
│   └── features/
│       ├── home/
│       │   └── presentation/
│       │       └── home_screen.dart          # Landing: Upload or Record CTA
│       │
│       ├── record/
│       │   ├── data/
│       │   │   └── record_service.dart       # CameraController lifecycle wrapper
│       │   └── presentation/
│       │       ├── record_screen.dart        # Entry screen with "Start Recording" button
│       │       ├── camera_record_screen.dart # Live preview + record controls
│       │       └── record_viewmodel.dart     # Recording state (ChangeNotifier)
│       │
│       ├── upload/
│       │   ├── data/
│       │   │   └── fastpix_upload_engine.dart # Session creation, PUT upload, playback polling
│       │   └── presentation/
│       │       ├── upload_screen.dart        # Upload UI (all status states)
│       │       ├── upload_viewmodel.dart     # Upload orchestration (ChangeNotifier)
│       │       └── upload_state.dart         # UploadStatus enum
│       │
│       └── playback/
│           └── presentation/
│               ├── video_player_screen.dart      # HLS player + share/copy UI
│               └── video_player_viewmodel.dart   # Playback state (ChangeNotifier)
│
├── test/                           # Unit and widget tests (to be added)
└── pubspec.yaml                    # Dependencies and asset declarations
```

---

## ✅ Prerequisites

Ensure the following are installed and configured before proceeding:

| Tool | Minimum Version | Notes |
|---|---|---|
| Flutter SDK | 3.0.0 | `flutter --version` |
| Dart SDK | 3.0.0 | Bundled with Flutter |
| Android Studio | Flamingo+ | For Android SDK & emulator |
| Xcode | 14+ | macOS only, required for iOS builds |
| CocoaPods | 1.11+ | `pod --version` |
| Git | Any | Required for the `fastpix_resumable_uploader` git dependency |
| Physical device or capable emulator | — | Camera plugin requires real camera hardware |

---

## 📦 Installation

```bash
# 1. Clone the repository
git clone https://github.com/your-org/streamgate_flutter.git
cd streamgate_flutter

# 2. Install Flutter dependencies
flutter pub get

# 3. iOS only — install CocoaPods dependencies
cd ios && pod install && cd ..

# 4. Verify your setup
flutter doctor -v
```

---

## ⚙️ Configuration

### FastPix Credentials

> ⚠️ **IMPORTANT — read the [Security Notes](#-security-notes) before committing this file to any repository.**

Open `lib/core/utils/constants.dart` and replace the placeholder values with your FastPix credentials:

```dart
class FastPixConstants {
  static const String tokenId   = "YOUR_FASTPIX_TOKEN_ID";
  static const String secretKey = "YOUR_FASTPIX_SECRET_KEY";
  static const String uploadApi = "https://api.fastpix.io/v1/on-demand/upload";
}
```

You can obtain credentials from the [FastPix Dashboard](https://dashboard.fastpix.io).

### Recommended: Build-time Injection via `--dart-define`

Avoid hardcoding secrets. Pass them at build time instead:

```bash
flutter run \
  --dart-define=FASTPIX_TOKEN_ID=your_token \
  --dart-define=FASTPIX_SECRET_KEY=your_secret
```

Update `constants.dart` to read from the environment:

```dart
class FastPixConstants {
  static const String tokenId   = String.fromEnvironment('FASTPIX_TOKEN_ID');
  static const String secretKey = String.fromEnvironment('FASTPIX_SECRET_KEY');
}
```

For CI/CD pipelines, store secrets in your pipeline's secret store (GitHub Actions Secrets, Bitrise Secrets, etc.) and inject via the `--dart-define` flag in your build step.

---

## ▶️ Running the App

```bash
# List connected devices
flutter devices

# Run in debug mode (hot reload enabled)
flutter run

# Run on a specific device
flutter run -d <device-id>

# Run with explicit credentials (recommended)
flutter run \
  --dart-define=FASTPIX_TOKEN_ID=xxx \
  --dart-define=FASTPIX_SECRET_KEY=yyy
```

---

## 📦 Building for Production

### Android

```bash
# Release APK (sideloadable)
flutter build apk --release \
  --dart-define=FASTPIX_TOKEN_ID=xxx \
  --dart-define=FASTPIX_SECRET_KEY=yyy

# App Bundle (for Google Play)
flutter build appbundle --release \
  --dart-define=FASTPIX_TOKEN_ID=xxx \
  --dart-define=FASTPIX_SECRET_KEY=yyy
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### iOS

```bash
flutter build ios --release \
  --dart-define=FASTPIX_TOKEN_ID=xxx \
  --dart-define=FASTPIX_SECRET_KEY=yyy
```

Then open `ios/Runner.xcworkspace` in Xcode, select your provisioning profile, and archive for distribution.

---

## 📱 Platform Setup

### Android — `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28"/>
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>

<!-- Required for camera plugin on older Android -->
<uses-feature android:name="android.hardware.camera" android:required="false"/>
```

### iOS — `ios/Runner/Info.plist`

```xml
<key>NSCameraUsageDescription</key>
<string>StreamGate needs camera access to record videos.</string>

<key>NSMicrophoneUsageDescription</key>
<string>StreamGate needs microphone access to record audio with video.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>StreamGate needs photo library access to upload videos.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>StreamGate needs permission to save videos to your library.</string>
```

### iOS — App Transport Security

FastPix uses HTTPS exclusively, so no ATS exceptions are needed. If you add any HTTP-only endpoints during development, add appropriate ATS exceptions in `Info.plist`.

---

## 🔌 API Integration

StreamGate integrates with three FastPix API surfaces. No custom backend is required — all calls originate from the app using HTTP Basic Auth.

### 1 · Create Upload Session

```
POST https://api.fastpix.io/v1/on-demand/upload
Authorization: Basic base64(tokenId:secretKey)
Content-Type: application/json
```

```json
{
  "corsOrigin": "*",
  "pushMediaSettings": {
    "metadata": { "uploadedBy": "flutter" },
    "accessPolicy": "public",
    "maxResolution": "1080p"
  }
}
```

**Response fields used by the app:**

| Field | Used for |
|---|---|
| `data.url` | Signed PUT destination |
| `data.uploadId` | Reference for polling |

### 2 · Upload File

```
PUT {signed_url_from_session}
Content-Type: application/octet-stream

[raw video bytes]
```

Progress is tracked via Dio's `onSendProgress` callback and surfaced as a `LinearProgressIndicator` in the UI.

### 3 · Poll Media Status

```
GET https://api.fastpix.io/v1/on-demand/{uploadId}
Authorization: Basic base64(tokenId:secretKey)
```

The app polls every **3 seconds**, up to **120 attempts** (~6 minutes). Once `status == "Ready"` and `playbackIds` is populated, polling stops and the playback screen is shown.

```json
{
  "data": {
    "status": "Ready",
    "playbackIds": [{ "id": "abc123xyz" }]
  }
}
```

### URL Patterns

| Purpose | URL |
|---|---|
| HLS stream (in-app player) | `https://stream.fastpix.io/{playbackId}.m3u8` |
| Web player (share link) | `https://play.fastpix.io/?playbackId={playbackId}&muted=false&hide-controls=false&accent-color=ff6100&primary-color=ffffff` |

---

## 🔄 App Flow

```
┌──────────────────────────────┐
│         Home Screen          │
│  [Upload Video] [Record Video]│
└──────┬───────────────┬───────┘
       │               │
       ▼               ▼
┌─────────────┐  ┌─────────────────┐
│  Gallery    │  │  Record Screen  │
│  Picker     │  │  (entry gate)   │
└──────┬──────┘  └────────┬────────┘
       │                  │
       │          ┌───────▼──────────────┐
       │          │  Camera Record Screen │
       │          │  Live preview + FAB  │
       │          │  Stop → auto-navigate │
       │          └───────┬──────────────┘
       │                  │
       └──────────┬────────┘
                  ▼
       ┌──────────────────────┐
       │    Upload Screen     │
       │  idle → uploading    │
       │  → processing        │
       │  → success / failed  │
       └──────────┬───────────┘
                  │ on success
                  ▼
       ┌──────────────────────┐
       │  Video Player Screen │
       │  HLS playback        │
       │  Copy / Share URL    │
       └──────────────────────┘
```

### Upload State Machine

```
idle ──pick/record──▶ uploading ──PUT complete──▶ processing ──Ready──▶ success
                          │                           │
                        error                       error
                          └───────────────────────▶ failed ──retry──▶ idle
```

---

## 🧩 State Management

StreamGate uses Flutter's built-in `ChangeNotifier` pattern — no external state library.

Each screen creates its ViewModel, calls `addListener(() => setState((){}))`, and reads state directly from the ViewModel's public fields.

```dart
// Example: UploadScreen wiring
viewModel = UploadViewModel(AppDI.fastPixEngine);
viewModel.addListener(() => setState(() {}));
```

ViewModels expose:
- **Status enum** — drives which widget subtree renders
- **Progress value** — `0.0 – 1.0` for the progress bar
- **Result data** — `playbackId`, `errorMessage` etc.

`AppDI` holds the single instance of `FastPixUploadService` so it can be shared across screens without rebuilding the HTTP client:

```dart
class AppDI {
  static final FastPixUploadService fastPixEngine = FastPixUploadService(
    tokenId: FastPixConstants.tokenId,
    secretKey: FastPixConstants.secretKey,
  );
}
```

---

## 🔒 Security Notes

> The default codebase ships with **hardcoded API credentials** in `constants.dart`. This is intentional for sample/demo purposes only.

**Before any public commit or production release:**

1. **Remove credentials from source code.** Use `--dart-define`, a `.env` loader, or a remote config service.
2. **Add `constants.dart` to `.gitignore`** if it must contain local credentials during development:
   ```
   # .gitignore
   lib/core/utils/constants.dart
   ```
3. **Rotate credentials immediately** if they were ever committed to a public repository.
4. **Consider a backend proxy.** The `secretKey` being present in a mobile binary is a risk — anyone who decompiles the APK can extract it. A backend service that vends short-lived signed URLs is the production-grade approach.
5. **Scope your API key** in the FastPix dashboard to the minimum required permissions.

---

## ⚡ Performance Considerations

| Area | Current Behaviour | Recommendation |
|---|---|---|
| File loading | Entire file read into memory with `readAsBytes()` | Stream bytes with `MultipartFile.fromFile()` or chunked reads for large videos |
| Recording resolution | `ResolutionPreset.low` | Expose as a user setting; default to `medium` or `high` for quality output |
| Polling interval | 3 s × 120 attempts | Add exponential back-off; cancel polling if the screen is disposed |
| Player retry | 3 retries with 3 s delay | Acceptable; ensure `mounted` checks are present (already done) |
| Controller lifecycle | `CameraController` disposed in `dispose()` | Correct; ensure no async operations continue after unmount |

---

## 🐛 Troubleshooting

| Symptom | Likely Cause | Resolution |
|---|---|---|
| Black camera preview on emulator | Emulator has no physical camera | Test on a real device or use an emulator with a virtual camera scene |
| `Invalid session response` | Wrong credentials or network issue | Verify `tokenId` / `secretKey` in `constants.dart`; check FastPix dashboard |
| Upload stuck at 100% indefinitely | Video is still transcoding | Normal — the app polls for up to 6 min; check FastPix dashboard for status |
| HLS player fails with error after retries | Video not yet ready, or wrong `playbackId` | Wait longer; cross-check `playbackId` in the FastPix dashboard |
| `pub get` fails on `fastpix_resumable_uploader` | Git not installed or GitHub unreachable | Ensure `git` is in `PATH`; check internet connectivity |
| iOS build fails — missing permissions | `Info.plist` entries absent | Add camera, microphone, and photo library usage descriptions |
| `MissingPluginException` on camera | Plugin not linked | Run `flutter clean && flutter pub get && cd ios && pod install` |
| App crashes on large video upload | OOM from `readAsBytes()` | Limit video duration or switch to a streaming upload strategy |

---

## 🗺 Roadmap

These improvements are inferred from the current codebase structure and existing stubs:

- [ ] **Backend proxy for credential security** — move session creation server-side
- [ ] **True resumable uploads** — `pause()` / `resume()` stubs exist in `FastPixUploadEngine`; implement chunked TUS-based upload
- [ ] **Upload history screen** — persist `playbackId` list locally with `shared_preferences` or `Hive`
- [ ] **Riverpod migration** — dependency is already declared in `pubspec.yaml`
- [ ] **Configurable recording settings** — resolution, front/rear camera toggle
- [ ] **Download video** — save processed video locally after upload
- [ ] **Thumbnail generation** — show a thumbnail in upload history from the FastPix image API
- [ ] **Unit & widget tests** — `flutter_test` is already a dev dependency; ViewModel logic is easily testable
- [ ] **Deep link support** — open the app directly to the player via a `play.fastpix.io` URL

---

## 🤝 Contributing

Contributions are welcome. Please follow the workflow below.

```bash
# 1. Fork and clone
git clone https://github.com/your-org/streamgate_flutter.git

# 2. Create a feature branch
git checkout -b feat/my-feature

# 3. Make changes, then analyze
flutter analyze

# 4. Run any existing tests
flutter test

# 5. Commit with a conventional commit message
git commit -m "feat(upload): add chunked upload support"

# 6. Push and open a pull request
git push origin feat/my-feature
```

### Coding Standards

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) style guidelines.
- Use `AppLogger.log()` — never raw `print()` statements.
- Keep screens thin: all business logic belongs in ViewModels and Service classes.
- Screens must only import from their own feature's `presentation/` layer and from `core/`. Never import across feature boundaries at the data layer.
- New features must follow the same `data/ | presentation/` vertical slice structure.

---

## 📄 License

```
MIT License

Copyright (c) 2024 StreamGate Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

<div align="center">

Built with  using [Flutter](https://flutter.dev) · Powered by [FastPix](https://fastpix.io)

</div>