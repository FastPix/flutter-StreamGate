import 'package:flutter/material.dart';
import 'upload_state.dart';
import '../data/fastpix_upload_engine.dart';
import '../../../core/utils/app_logger.dart';

class UploadViewModel extends ChangeNotifier {
  final FastPixUploadService service;

  UploadViewModel(this.service);

  UploadStatus status = UploadStatus.idle;
  double progress = 0;
  String? uploadId;
  String? playbackId;
  String? errorMessage;

  Future<void> uploadVideo(String filePath) async {
    try {
      //  BEFORE UPLOAD
      AppLogger.log("🚀 Starting upload...");
      AppLogger.log("📁 File path: $filePath");

      status = UploadStatus.uploading;
      progress = 0;
      errorMessage = null;
      notifyListeners();

      uploadId = await service.uploadFile(
        filePath: filePath,
        onProgress: (p) {
          progress = p;
          notifyListeners();
        },
      );

      //  AFTER UPLOAD
      AppLogger.log("📦 Upload completed");
      AppLogger.log("📦 Upload ID: $uploadId");

      status = UploadStatus.processing;
      notifyListeners();

      //  BEFORE PLAYBACK FETCH
      AppLogger.log("🎬 Fetching playback ID...");

      playbackId = await service.getPlaybackId(uploadId!);

      // SUCCESS
      AppLogger.log("Playback ID received: $playbackId");

      status = UploadStatus.success;
      notifyListeners();
    } catch (e) {
      //  ERROR LOGGING
      AppLogger.log(" Upload/ViewModel Error: $e");

      status = UploadStatus.failed;
      errorMessage = e.toString();
      notifyListeners();
    }
  }
}
