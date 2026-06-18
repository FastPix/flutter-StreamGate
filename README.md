# StreamGate Flutter App

StreamGate is an open-source cross-platform Flutter application designed as a technical showcase for capturing and uploading video content directly to the cloud. Built purely for developers, it demonstrates how to handle complex mobile media workflows — such as camera capture, resumable direct-to-cloud uploads, and HLS playback using FastPix infrastructure.

Once an upload completes, StreamGate generates an instant, shareable playback link.

---

## Core Features & Architecture

StreamGate is built using a modern Flutter tech stack (Dart, Flutter, camera, video_player, chewie) and focuses on the following core capabilities:

1. **Camera Capture**: Integrates the `camera` Flutter plugin (`CameraController`) for native video recording directly within the app on both Android and iOS.
2. **Direct Cloud Uploading**: Utilizes the `fastpix_resumable_uploader` package to push large media files securely to the cloud in resumable chunks — without routing them through an intermediary backend server.
3. **Upload Progress Tracking**: Streams real-time upload progress back to the UI via a `ChangeNotifier`-based `UploadViewModel` following the MVVM pattern.
4. **HLS Playback**: Integrates `video_player` and `chewie` to stream the processed video directly from FastPix's CDN using the generated HLS playback URL (`stream.fastpix.com/{playbackId}.m3u8`).
5. **Share Playback Link**: Uses `share_plus` to instantly share the FastPix playback link once upload and processing completes.

---

## Tech Stack & Dependencies

* **Language**: Dart
* **UI Framework**: Flutter (Material 3)
* **Camera**: `camera` plugin (`CameraController`, `ResolutionPreset`)
* **Networking**: `dio` (HTTP client for upload session creation and status polling)
* **Uploading**: [`fastpix_resumable_uploader`](https://pub.dev/packages/fastpix_resumable_uploader) — resumable chunked uploads via FastPix
* **Playback**: `video_player` + `chewie` (HLS stream via `stream.fastpix.com`)
* **Sharing**: `share_plus`
* **Architecture**: MVVM (`ChangeNotifier` ViewModels, repository pattern, manual DI via `AppDI`)
* **Build Constraints**: Flutter 3.x+, Dart 3.x+, iOS 13.0+, Android minSdk per Flutter default

---

## Setup & Build Instructions

### Prerequisites

Before building the project, ensure you have:

* Flutter 3.x+ and Dart 3.x+ (run `flutter doctor` to verify)
* Xcode 15+ (for iOS builds)
* Android Studio / Android SDK (for Android builds)
* Physical device recommended for camera recording
* FastPix API credentials

---

### 1. Clone Repository

```bash
 git clone https://github.com/FastPix/flutter-StreamGate.git
cd flutter-StreamGate
flutter pub get
```

---

### 2. Add FastPix Resumable Uploader

StreamGate uses the [`fastpix_resumable_uploader`](https://pub.dev/packages/fastpix_resumable_uploader) package for resumable chunked uploads.

Add it to your `pubspec.yaml`:

```yaml
dependencies:
  fastpix_resumable_uploader: ^latest
```

Then run:

```bash
flutter pub get
```

For full SDK setup instructions refer to the official guide: [Set up Resumable Uploads for Flutter](https://fastpix.com/docs/upload-videos/set-up-resumable-uploads-for-flutter)

---

### 3. Configure FastPix Credentials

Add your FastPix credentials in `lib/core/constants/fastpix_constants.dart`:

```dart
class FastPixConstants {
  static const String tokenId = "YOUR_TOKEN_ID_HERE";

  static const String secretKey = "YOUR_SECRET_KEY_HERE";

  static const String uploadApi = "https://api.fastpix.com/v1/on-demand/upload";
}
```

For production builds, store credentials securely using environment variables or a secrets manager. Never commit credentials to version control.

To get your FastPix API credentials visit: [Activate Your Account](https://fastpix.com/docs/getting-started/activate-your-account)

---

### 4. Configure iOS Permissions

Add the following keys to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Used to record videos.</string>

<key>NSMicrophoneUsageDescription</key>
<string>Used to record audio.</string>
```

---

### 5. Configure Android Permissions

Add the following permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

---

### 6. Build & Run

**iOS**

```bash
cd ios && pod install && cd ..
flutter run
```

**Android**

```bash
flutter run
```

**Using an IDE**

1. Open the project root in Android Studio or VS Code
2. Select your target device (physical device recommended for camera)
3. Run via **Run → Run 'main.dart'**

**Clean build if needed:**

```bash
flutter clean
flutter pub get
flutter run
```

## Important Reference Links

* FastPix Platform: [fastpix.com](https://fastpix.com/)
* FastPix Access Token Guide: [Activate Your Account](https://fastpix.com/docs/getting-started/activate-your-account)
* FastPix VOD Upload API Docs: [Direct Upload Video Media](https://fastpix.com/docs/video-on-demand-api/upload-and-import-videos/direct-upload-video-media)
* FastPix Resumable Uploader: [fastpix_resumable_uploader — pub.dev](https://pub.dev/packages/fastpix_resumable_uploader)
* Flutter Camera Plugin: [camera — pub.dev](https://pub.dev/packages/camera)
* Flutter Video Player: [video_player — pub.dev](https://pub.dev/packages/video_player)

---

## License

MIT License.