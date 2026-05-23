import UIKit
import Flutter
import AVFoundation

// ─────────────────────────────────────────────────────────────────────────────
// AppDelegate
//
// This app uses a scene-based lifecycle (FlutterSceneDelegate in SceneDelegate.swift).
// The MethodChannel for screen recording is registered in SceneDelegate, NOT here,
// because AppDelegate.window is nil in scene-based apps — any channel setup here
// would silently fail and produce MissingPluginException on every call.
//
// AppDelegate's only responsibilities:
//   • Register Flutter plugins
//   • Configure AVAudioSession so the Runner process stays alive during broadcast
// ─────────────────────────────────────────────────────────────────────────────

@main
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        GeneratedPluginRegistrant.register(with: self)

        // Keep the Runner process alive while the broadcast extension records.
        // Required for the app to receive the recording path when it resumes.
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .default,
            options: []
        )

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}