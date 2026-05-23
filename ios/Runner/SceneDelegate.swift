import Flutter
import UIKit
import ReplayKit
import AVFoundation

// ─────────────────────────────────────────────────────────────────────────────
// SceneDelegate
//
// WHY the channel lives here and not in AppDelegate:
//   This app uses a scene-based lifecycle (UISceneConfiguration in Info.plist).
//   In scene-based apps the UIWindow is owned by the UIWindowScene / SceneDelegate,
//   NOT by AppDelegate.  So `AppDelegate.window` is nil and any attempt to grab
//   `window?.rootViewController as? FlutterViewController` in AppDelegate always
//   fails — causing MissingPluginException on every channel call.
//
//   The correct place to set up MethodChannels is here, in
//   scene(_:willConnectTo:options:), where the FlutterViewController is
//   guaranteed to exist and `window` is already set.
// ─────────────────────────────────────────────────────────────────────────────

class SceneDelegate: FlutterSceneDelegate {

    // ── Constants ─────────────────────────────────────────────────────────────
    // APP_GROUP must match SampleHandler.swift and both .entitlements files.
    private let CHANNEL                = "streamgate/screen_record"
    private let APP_GROUP              = "group.streamgate.shared"
    private let PATH_KEY               = "recordedVideoURL"
    private let TS_KEY                 = "recordingFinishedAt"
    // Must match PRODUCT_BUNDLE_IDENTIFIER of the StreamGateBroadcast target.
    private let BROADCAST_EXTENSION_ID = "com.example.streamgateFlutter.StreamGateBroadcast"

    // ─────────────────────────────────────────────────────────────────────────
    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)

        // At this point FlutterSceneDelegate has already set self.window and
        // its rootViewController is a FlutterViewController.
        guard let vc = window?.rootViewController as? FlutterViewController else {
            print("⚠️ [SceneDelegate] rootViewController is not FlutterViewController — channel not registered")
            return
        }

        setupMethodChannel(messenger: vc.binaryMessenger)

        // Keep the Runner process alive during broadcast extension recording.
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .default,
            options: []
        )
    }

    // ─────────────────────────────────────────────────────────────────────────
    // METHOD CHANNEL SETUP
    // ─────────────────────────────────────────────────────────────────────────
    private func setupMethodChannel(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: CHANNEL,
            binaryMessenger: messenger
        )

        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }

            switch call.method {

            // ── Trigger the ReplayKit broadcast picker ────────────────────
            case "startScreenRecording":
                DispatchQueue.main.async { self.showBroadcastPicker() }
                // Return immediately — the extension is a separate OS process;
                // there is no synchronous handshake.
                result(true)

            // ── Non-blocking poll for a finalized recording ───────────────
            // The extension writes the path to UserDefaults when
            // finishWriting() completes.  Flutter polls this on app-resume.
            case "checkRecordingReady":
                self.printSentinelDiagnostics()
                result(self.readFinalizedPath())

            // ── Clear state after a successful upload ─────────────────────
            case "clearRecording":
                self.clearSharedState()
                result(true)

            // ── Request a programmatic stop in the extension ──────────────
            case "stopScreenRecording":
                let defaults = UserDefaults(suiteName: self.APP_GROUP)
                defaults?.set(true, forKey: "shouldStopRecording")
                defaults?.synchronize()
                print("🛑 [SceneDelegate] Programmatic stop request written to UserDefaults")
                result(true)

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        print("✅ [SceneDelegate] MethodChannel '\(CHANNEL)' registered on FlutterViewController.binaryMessenger")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SENTINEL DIAGNOSTICS
    // Printed on every checkRecordingReady call so you can see the full
    // App Group state in the Xcode console without a separate button tap.
    // ─────────────────────────────────────────────────────────────────────────
    private func printSentinelDiagnostics() {
        let container   = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: APP_GROUP)
        let sentinel    = container?.appendingPathComponent("EXTENSION_RAN.txt")
        let fileExists  = sentinel.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        let lastRan     = UserDefaults(suiteName: APP_GROUP)?.object(forKey: "extensionLastRan") as? Date
        let contents    = sentinel.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "nil"
        let videoPath   = UserDefaults(suiteName: APP_GROUP)?.string(forKey: PATH_KEY) ?? "nil"
        let videoExists = videoPath != "nil" && FileManager.default.fileExists(atPath: videoPath)

        let logURL      = container?.appendingPathComponent("LIFECYCLE.log")
        let logContents = logURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "nil"

        print(
        """
        ───────── EXTENSION SENTINEL CHECK ─────────
        container URL   : \(container?.path ?? "❌ nil — App Group not configured on Runner target")
        sentinel path   : \(sentinel?.path ?? "n/a")
        file exists     : \(fileExists ? "✅ YES" : "❌ NO")
        file contents   : \(contents)
        last ran (UD)   : \(lastRan.map { "\($0)" } ?? "nil")
        recordedVideoURL: \(videoPath)
        video on disk   : \(videoExists ? "✅ YES" : "❌ NO")
        LIFECYCLE LOG   : \(logContents)
        ────────────────────────────────────────────
        """
        )
    }

    // ─────────────────────────────────────────────────────────────────────────
    // READ FINALIZED PATH FROM APP GROUP
    // ─────────────────────────────────────────────────────────────────────────
    private func readFinalizedPath() -> String? {
        let defaults = UserDefaults(suiteName: APP_GROUP)
        defaults?.synchronize()

        guard
            let path = defaults?.string(forKey: PATH_KEY),
            !path.isEmpty,
            FileManager.default.fileExists(atPath: path)
        else { return nil }

        return path
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CLEAR SHARED STATE  — call after a successful upload
    // ─────────────────────────────────────────────────────────────────────────
    private func clearSharedState() {
        let defaults = UserDefaults(suiteName: APP_GROUP)
        defaults?.removeObject(forKey: PATH_KEY)
        defaults?.removeObject(forKey: TS_KEY)
        defaults?.synchronize()
        print("🗑️ [SceneDelegate] Shared state cleared (post-upload)")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SHOW REPLAYKIT BROADCAST PICKER
    // ─────────────────────────────────────────────────────────────────────────
    private func showBroadcastPicker() {
        let picker = RPSystemBroadcastPickerView(
            frame: CGRect(x: 0, y: 0, width: 44, height: 44)
        )
        picker.preferredExtension = BROADCAST_EXTENSION_ID
        picker.showsMicrophoneButton = false

        if let button = picker.subviews.first(where: { $0 is UIButton }) as? UIButton {
            button.sendActions(for: .touchUpInside)
            print("🚀 [SceneDelegate] Broadcast Picker triggered — extension: \(BROADCAST_EXTENSION_ID)")
        } else {
            print("⚠️ [SceneDelegate] Picker button not found — picker may not appear")
        }
    }
}