import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'record_service.dart';

/// Unified screen recording service for iOS (ReplayKit) and Android (MediaProjection).
///
/// iOS  → fire-and-forget start; path arrives asynchronously via [checkRecordingReady].
/// Android → [stopRecording] returns the MP4 path directly (synchronous).
class ScreenRecordService {
  static const _channel = MethodChannel('streamgate/screen_record');

  final RecordService _androidFallback = RecordService();

  Future<void> startRecording() async {
    if (Platform.isIOS) {
      try {
        await _channel.invokeMethod<bool>('startScreenRecording');
      } catch (e) {
        debugPrint('startRecording error: $e');
      }
    } else if (Platform.isAndroid) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      await _androidFallback.startScreenRecording('screen_$ts');
    }
  }

  /// Returns the MP4 path on Android; null on iOS (path arrives via [checkRecordingReady]).
  Future<String?> stopRecording() async {
    if (Platform.isIOS) {
      try {
        await _channel.invokeMethod<bool>('stopScreenRecording');
      } catch (e) {
        debugPrint(' stopRecording error: $e');
      }
      return null;
    } else if (Platform.isAndroid) {
      return _androidFallback.stopScreenRecording();
    }
    return null;
  }

  /// iOS only — polls App Group UserDefaults for the finished MP4 path.
  Future<String?> checkRecordingReady() async {
    if (!Platform.isIOS) return null;
    try {
      return await _channel.invokeMethod<String>('checkRecordingReady');
    } catch (e) {
      debugPrint('checkRecordingReady error: $e');
      return null;
    }
  }

  /// iOS only — call after upload completes to reset App Group state.
  Future<void> clearRecording() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<bool>('clearRecording');
    } catch (e) {
      debugPrint(' clearRecording error: $e');
    }
  }
}