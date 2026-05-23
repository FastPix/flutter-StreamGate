
import ReplayKit
import AVFoundation

// ─────────────────────────────────────────────────────────────────────────────
// SampleHandler — ReplayKit Broadcast Upload Extension
//
// KEY RULES:
//   1. broadcastFinished() NEVER blocks.  The ReplayKit watchdog SIGKILLs the
//      extension if broadcastFinished() doesn't return in ~2-3 s.
//      The finishWriting closure runs ASYNCHRONOUSLY on AVFoundation's queue.
//
//   2. tmpURL  → NSTemporaryDirectory() of the EXTENSION sandbox.
//      finalURL → shared App Group container (readable by the main app).
//      FileManager.moveItem works across these two locations.
//
//   3. All shared state mutations happen on ReplayKit's serial queue
//      (processSampleBuffer is always called on it), so no extra locks.
//
//   4. APP_GROUP must match AppDelegate.swift and all .entitlements files.
// ─────────────────────────────────────────────────────────────────────────────

class SampleHandler: RPBroadcastSampleHandler {

    // ── App Group identifiers ────────────────────────────────────────────────
    private static let appGroup = "group.streamgate.shared"   // ← keep in sync
    private static let pathKey  = "recordedVideoURL"
    private static let tsKey    = "recordingFinishedAt"

    // ── AVAssetWriter pipeline ───────────────────────────────────────────────
    private var writer:        AVAssetWriter?
    private var videoInput:    AVAssetWriterInput?
    private var tmpURL:        URL?
    private var finalURL:      URL?
    private var sessionStarted = false

    // ── Diagnostics ──────────────────────────────────────────────────────────
    private var frameCount    = 0
    private var appendedCount = 0

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: App Group container
    // ─────────────────────────────────────────────────────────────────────────
    private static func container() -> URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup
        )
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Lifecycle log (persists across extension death for debugging)
    // ─────────────────────────────────────────────────────────────────────────
    private static func log(_ stage: String, _ detail: String = "") {
        guard let dir = container() else { return }
        let line = "[\(Date())] \(stage) \(detail)\n"
        let url  = dir.appendingPathComponent("LIFECYCLE.log")

        if let fh = try? FileHandle(forWritingTo: url) {
            fh.seekToEndOfFile()
            fh.write(line.data(using: .utf8) ?? Data())
            try? fh.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // Write a sentinel file so the debug button can verify the extension ran
    private static func writeSentinel(_ message: String) {
        guard let dir = container() else { return }
        let url = dir.appendingPathComponent("EXTENSION_RAN.txt")
        try? message.write(to: url, atomically: true, encoding: .utf8)
        // Also persist the timestamp in UserDefaults for the sentinel check
        UserDefaults(suiteName: appGroup)?.set(Date(), forKey: "extensionLastRan")
        UserDefaults(suiteName: appGroup)?.synchronize()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: broadcastStarted
    // ─────────────────────────────────────────────────────────────────────────
    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // Clear previous log + sentinel from last session
        if let dir = Self.container() {
            try? FileManager.default.removeItem(
                at: dir.appendingPathComponent("LIFECYCLE.log")
            )
            try? FileManager.default.removeItem(
                at: dir.appendingPathComponent("EXTENSION_RAN.txt")
            )
        }

        // Clear leftover path so the main app can't accidentally pick it up
        let ud = UserDefaults(suiteName: Self.appGroup)
        ud?.removeObject(forKey: Self.pathKey)
        ud?.removeObject(forKey: Self.tsKey)
        ud?.synchronize()

        // Write sentinel to prove the extension process launched successfully
        Self.writeSentinel("Extension launched at \(Date())")

        let fileName = "\(UUID().uuidString).mp4"
        let tmp      = URL(fileURLWithPath: NSTemporaryDirectory())
                          .appendingPathComponent(fileName)

        guard let container = Self.container() else {
            Self.log("ERR_NO_CONTAINER",
                     "App Group '\(Self.appGroup)' not accessible from extension — " +
                     "check entitlements on BOTH Runner and StreamGateBroadcast targets")
            finishBroadcastWithError(
                NSError(domain: "SampleHandler", code: 1,
                        userInfo: [NSLocalizedDescriptionKey:
                            "App Group container unavailable. " +
                            "Ensure group.\(Self.appGroup) is enabled in both entitlements."])
            )
            return
        }

        tmpURL   = tmp
        finalURL = container.appendingPathComponent(fileName)

        try? FileManager.default.removeItem(at: tmp)

        do {
            writer = try AVAssetWriter(outputURL: tmp, fileType: .mp4)
            Self.log("BROADCAST_STARTED", tmp.lastPathComponent)
        } catch {
            Self.log("ERR_WRITER_INIT", error.localizedDescription)
            finishBroadcastWithError(error)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: processSampleBuffer
    // ─────────────────────────────────────────────────────────────────────────
    override func processSampleBuffer(
        _ sampleBuffer: CMSampleBuffer,
        with sampleBufferType: RPSampleBufferType
    ) {
        autoreleasepool {
            // Check for stop request from the main app
            let ud = UserDefaults(suiteName: Self.appGroup)
            if ud?.bool(forKey: "shouldStopRecording") == true {
                ud?.removeObject(forKey: "shouldStopRecording")
                ud?.synchronize()
                
                Self.log("PROGRAMMATIC_STOP_REQUESTED")
                let selector = NSSelectorFromString("finishBroadcastWithError:")
                if self.responds(to: selector) {
                    self.perform(selector, with: nil)
                }
                return
            }

            guard
                sampleBufferType == .video,
                CMSampleBufferDataIsReady(sampleBuffer)
            else { return }

            frameCount += 1

            // Lazily create the video input on the first frame so we get the
            // real pixel dimensions from the CMFormatDescription.
            if videoInput == nil {
                guard
                    let fmt = CMSampleBufferGetFormatDescription(sampleBuffer),
                    let w   = writer,
                    w.status == .unknown
                else { return }

                let dim    = CMVideoFormatDescriptionGetDimensions(fmt)
                let width  = Int(dim.width)  - (Int(dim.width)  % 16)
                let height = Int(dim.height) - (Int(dim.height) % 16)

                let settings: [String: Any] = [
                    AVVideoCodecKey:  AVVideoCodecType.h264,
                    AVVideoWidthKey:  width,
                    AVVideoHeightKey: height,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey:          2_000_000,
                        AVVideoProfileLevelKey:            AVVideoProfileLevelH264HighAutoLevel,
                        AVVideoMaxKeyFrameIntervalKey:     60,
                    ]
                ]

                let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
                input.expectsMediaDataInRealTime = true

                guard w.canAdd(input) else {
                    Self.log("ERR_CANNOT_ADD_INPUT")
                    return
                }

                w.add(input)
                videoInput = input
                Self.log("INPUT_ADDED", "\(width)x\(height)")
            }

            guard let w = writer, let vi = videoInput else { return }

            if w.status == .failed {
                Self.log("ERR_WRITER_STATUS_FAILED", w.error?.localizedDescription ?? "unknown")
                return
            }

            if w.status == .unknown {
                guard w.startWriting() else {
                    Self.log("ERR_START_WRITING_FAILED",
                             w.error?.localizedDescription ?? "unknown")
                    return
                }
                w.startSession(
                    atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                )
                sessionStarted = true
                Self.log("SESSION_STARTED")
            }

            if w.status == .writing, vi.isReadyForMoreMediaData {
                vi.append(sampleBuffer)
                appendedCount += 1
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: broadcastFinished  ← CRITICAL: must return immediately
    // ─────────────────────────────────────────────────────────────────────────
    override func broadcastFinished() {
        Self.log("BROADCAST_FINISHED", "frames=\(frameCount) appended=\(appendedCount)")

        guard
            let w = writer,
            w.status == .writing
        else {
            Self.log("ERR_WRITER_NOT_WRITING",
                     "status=\(writer?.status.rawValue ?? -1)")
            markFinished(path: nil)
            return
        }

        videoInput?.markAsFinished()

        let tmp   = tmpURL
        let final = finalURL

        let semaphore = DispatchSemaphore(value: 0)

        w.finishWriting {
            Self.log("FINISH_WRITING_DONE")

            guard let src = tmp, let dst = final else {
                Self.log("ERR_URLS_NIL")
                self.markFinished(path: nil)
                semaphore.signal()
                return
            }

            do {
                try? FileManager.default.removeItem(at: dst)
                try FileManager.default.moveItem(at: src, to: dst)
                Self.log("MOVED_TO_GROUP", dst.path)
                // Update sentinel with final status
                Self.writeSentinel("Recording complete at \(Date())\nFile: \(dst.lastPathComponent)")
                self.markFinished(path: dst.path)
            } catch {
                Self.log("ERR_MOVE_FAILED", error.localizedDescription)
                self.markFinished(path: nil)
            }
            semaphore.signal()
        }

        // Wait up to 2.0 seconds for finishWriting and file/UserDefaults operations to finish.
        _ = semaphore.wait(timeout: .now() + 2.0)
        Self.log("SEMAPHORE_WAIT_DONE")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Write result to shared UserDefaults
    // ─────────────────────────────────────────────────────────────────────────
    private func markFinished(path: String?) {
        let ud = UserDefaults(suiteName: Self.appGroup)
        if let p = path {
            ud?.set(p, forKey: Self.pathKey)
        }
        ud?.set(Date().timeIntervalSince1970, forKey: Self.tsKey)
        ud?.synchronize()
        Self.log("USERDEFAULTS_SAVED", path ?? "nil")
    }
}