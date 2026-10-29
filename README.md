# StreamGate - Flutter video upload demo app: record, resumable upload, HLS playback and share

[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-0CB16D)](https://github.com/FastPix/flutter-StreamGate)
[![Built with Flutter](https://img.shields.io/badge/Flutter-3.x-0CB16D)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](./LICENSE)

**StreamGate** is a ready-to-run, open-source Flutter app that shows the complete **record → upload → play → share** video flow end to end: record a video with the device camera, upload it to the cloud with **resumable, chunked uploads**, play it back over **HLS**, and share an instant playback link. It is the working example the generic "how to record and upload video in Flutter" tutorials leave out - camera capture, direct-to-cloud resumable upload, HLS streaming and sharing in one app.

Built purely for developers as a technical showcase, it uses the `camera` plugin for capture, the [`fastpix_resumable_uploader`](https://pub.dev/packages/fastpix_resumable_uploader) package to push large files to the cloud in resumable chunks (no intermediary backend), and `video_player` + `chewie` to stream the processed video over HLS from FastPix. Once an upload completes, StreamGate generates an instant, shareable playback link.

It is a **demo app, not an SDK or package** - clone it, add your FastPix credentials, and run it to see the full workflow, or lift the pieces you need into your own app.

**Works with:** Flutter (Android and iOS) · `camera` · `fastpix_resumable_uploader` · `video_player` + `chewie` (HLS) · `share_plus` · MVVM

[FastPix documentation](https://fastpix.com/docs/upload-videos/set-up-resumable-uploads-for-flutter) · [Create a free account](https://dashboard.fastpix.com/signup?utm_source=github&utm_medium=referral&utm_campaign=github_signup)

## Start here

Clone and run it in order:

1. [What StreamGate does](#core-features--architecture)
2. [Tech stack and dependencies](#tech-stack--dependencies)
3. [Prerequisites](#prerequisites)
4. [Clone the repository](#1-clone-repository)
5. [Configure your FastPix credentials](#2-configure-fastpix-credentials)
6. [Configure iOS and Android permissions](#3-configure-ios-permissions)
7. [Build and run](#5-build--run)
8. [How the upload package is included](#appendix-how-the-upload-package-is-included)
9. [FAQ](#faq)

## Who it's for

- **Developers adding "record and upload video" to a Flutter app:** a complete, copy-ready camera-capture plus resumable-upload flow instead of stitching tutorials together.
- **UGC and video-sharing apps:** record, upload to the cloud, get a shareable HLS link - the whole loop in one example.
- **Anyone learning the Flutter media pipeline:** see camera capture, direct-to-cloud resumable upload, HLS playback and sharing wired together with a clean MVVM structure.

---

## Core Features & Architecture

StreamGate is built using a modern Flutter tech stack (Dart, Flutter, camera, video_player, chewie) and focuses on the following core capabilities:

1. **Camera Capture**: Integrates the `camera` Flutter plugin (`CameraController`) for native video recording directly within the app on both Android and iOS.
2. **Direct Cloud Uploading**: Utilizes the `fastpix_resumable_uploader` package to push large media files securely to the cloud in resumable chunks - without routing them through an intermediary backend server.
3. **Upload Progress Tracking**: Streams real-time upload progress back to the UI via a `ChangeNotifier`-based `UploadViewModel` following the MVVM pattern.
4. **HLS Playback**: Integrates `video_player` and `chewie` to stream the processed video directly from FastPix's CDN using the generated HLS playback URL (`stream.fastpix.com/{playbackId}.m3u8`).
5. **Share Playback Link**: Uses `share_plus` to instantly share the FastPix playback link once upload and processing completes.

---

## Tech Stack & Dependencies

* **Language**: Dart
* **UI Framework**: Flutter (Material 3)
* **Camera**: `camera` plugin (`CameraController`, `ResolutionPreset`)
* **Networking**: `dio` (HTTP client for upload session creation and status polling)
* **Uploading**: [`fastpix_resumable_uploader`](https://pub.dev/packages/fastpix_resumable_uploader) - resumable chunked uploads via FastPix
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

`flutter pub get` installs every dependency, including the FastPix resumable uploader (already declared in `pubspec.yaml` - see [How the upload package is included](#appendix-how-the-upload-package-is-included)). You do not need to add it manually.

---

### 2. Configure FastPix Credentials

Add your FastPix credentials in `lib/core/utils/constants.dart`:

```dart
class FastPixConstants {
  static const String tokenId = "YOUR_TOKEN_ID_HERE";

  static const String secretKey = "YOUR_SECRET_KEY_HERE";
}
```

The upload API endpoint (`https://api.fastpix.com/v1/on-demand/upload`) is already set in the upload engine, so you only need to provide your `tokenId` and `secretKey`.

For production builds, store credentials securely using environment variables or a secrets manager. Never commit credentials to version control.

To get your FastPix API credentials visit: [Activate Your Account](https://fastpix.com/docs/getting-started/activate-your-account)

---

### 3. Configure iOS Permissions

These keys are already present in `ios/Runner/Info.plist`. If you are copying the flow into your own app, add them there:

```xml
<key>NSCameraUsageDescription</key>
<string>Used to record videos.</string>

<key>NSMicrophoneUsageDescription</key>
<string>Used to record audio.</string>
```

---

### 4. Configure Android Permissions

These permissions are already present in `android/app/src/main/AndroidManifest.xml`. If you are copying the flow into your own app, add them there:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

---

### 5. Build & Run

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

---

## Appendix: How the upload package is included

This demo already declares the FastPix resumable uploader in `pubspec.yaml`, so `flutter pub get` fetches it automatically - there is nothing to add for the demo. It is pinned to a specific commit of the [FastPix/flutter-uploads](https://github.com/FastPix/flutter-uploads) repository:

```yaml
dependencies:
  fastpix_resumable_uploader:
    git:
      url: https://github.com/FastPix/flutter-uploads
      ref: <commit-sha>
```

**Adding it to your own app:** the package is published on pub.dev as [`fastpix_resumable_uploader`](https://pub.dev/packages/fastpix_resumable_uploader). Add it with a real version constraint (check pub.dev for the current version), for example:

```yaml
dependencies:
  fastpix_resumable_uploader: ^1.0.0
```

Then run `flutter pub get`. For full setup instructions, see the official guide: [Set up Resumable Uploads for Flutter](https://fastpix.com/docs/upload-videos/set-up-resumable-uploads-for-flutter).

## FAQ

**How do I record and upload a video in Flutter?**
StreamGate shows the full flow: the `camera` plugin records the video, then `fastpix_resumable_uploader` uploads it to the cloud in resumable chunks. Clone the repo, add your credentials, and run it. See [What StreamGate does](#core-features--architecture) and [Build and run](#5-build--run).

**How do I upload a large video to the cloud from Flutter without my own backend?**
The app uploads directly to FastPix using a resumable, chunked uploader, so large files go straight to the cloud without routing through an intermediary server. See [How the upload package is included](#appendix-how-the-upload-package-is-included).

**How do I play the uploaded video back (HLS)?**
Once processing completes, StreamGate streams the video over HLS with `video_player` + `chewie` from `stream.fastpix.com/{playbackId}.m3u8`, then shares the playback link with `share_plus`. See [What StreamGate does](#core-features--architecture).

**Is this a package I can add to my app?**
No - it is a runnable demo app, not a package. Use it to see the end-to-end workflow and copy the parts you need. The upload engine it uses, `fastpix_resumable_uploader`, is a separate package you can add to your own app.

**Which platforms does it run on?**
Android and iOS. A physical device is recommended for camera recording.

**Do I need a FastPix account?**
Yes - you need FastPix API credentials to create upload URLs and get a playback link. [Create a free account](https://dashboard.fastpix.com/signup?utm_source=github&utm_medium=referral&utm_campaign=github_signup).

## Related FastPix Flutter repositories

| What you want | Repository |
| --- | --- |
| This record + upload + play demo app | **FastPix/flutter-StreamGate** (this repository) |
| The resumable upload package it uses | [FastPix/flutter-uploads](https://github.com/FastPix/flutter-uploads) (`fastpix_resumable_uploader`) |
| Play FastPix HLS video in Flutter | [FastPix/Flutter-Video-Player](https://github.com/FastPix/Flutter-Video-Player) |
| Add QoE analytics to a Flutter player | [FastPix/flutter-data-better-player](https://github.com/FastPix/flutter-data-better-player) |

## Important Reference Links

* FastPix Platform: [fastpix.com](https://fastpix.com/)
* FastPix Access Token Guide: [Activate Your Account](https://fastpix.com/docs/getting-started/activate-your-account)
* FastPix VOD Upload API Docs: [Direct Upload Video Media](https://fastpix.com/docs/video-on-demand-api/upload-and-import-videos/direct-upload-video-media)
* FastPix Resumable Uploader: [fastpix_resumable_uploader - pub.dev](https://pub.dev/packages/fastpix_resumable_uploader)
* Flutter Camera Plugin: [camera - pub.dev](https://pub.dev/packages/camera)
* Flutter Video Player: [video_player - pub.dev](https://pub.dev/packages/video_player)

---

## License

MIT License.
