import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../core/utils/app_logger.dart';

class FastPixUploadService {
  final String tokenId;
  final String secretKey;

  final Dio dio = Dio(
    BaseOptions(
      followRedirects: false,
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  CancelToken? _cancelToken;

  bool _isPaused = false;
  String? _lastUploadUrl;
  String? _lastUploadId;
  File? _lastFile;

  FastPixUploadService({
    required this.tokenId,
    required this.secretKey,
  });

  // ---------------- CREATE SESSION ----------------
  Future<Map<String, dynamic>> createUploadSession() async {
    final auth = "Basic ${base64Encode(utf8.encode('$tokenId:$secretKey'))}";

    final response = await dio.post(
      "https://api.fastpix.io/v1/on-demand/upload",
      options: Options(
        headers: {
          "Authorization": auth,
          "Content-Type": "application/json",
        },
      ),
      data: {
        "corsOrigin": "*",
        "pushMediaSettings": {
          "metadata": {"uploadedBy": "flutter"},
          "accessPolicy": "public",
          "maxResolution": "1080p",
        }
      },
    );

    AppLogger.log("🔵 SESSION RESPONSE: ${response.data}");

    final res = response.data;
    final data = res["data"] ?? res;

    final uploadUrl = data["url"] ?? data["signedUrl"] ?? "";
    final uploadId = data["uploadId"] ?? "";

    if (uploadUrl.isEmpty || uploadId.isEmpty) {
      throw Exception("Invalid session response: $res");
    }

    return {
      "uploadUrl": uploadUrl,
      "uploadId": uploadId,
    };
  }

  // ---------------- UPLOAD FILE ----------------
  Future<String> uploadFile({
    required String filePath,
    required Function(double progress) onProgress,
  }) async {
    final session = await createUploadSession();

    final uploadUrl = session["uploadUrl"];
    final uploadId = session["uploadId"];

    _lastUploadUrl = uploadUrl;
    _lastUploadId = uploadId;
    _lastFile = File(filePath);

    final bytes = await _lastFile!.readAsBytes();

    AppLogger.log("🟢 UPLOADING TO:");
    AppLogger.log(uploadUrl);
    AppLogger.log("FILE SIZE: ${bytes.length}");

    _cancelToken = CancelToken();
    _isPaused = false;

    final response = await dio.put(
      uploadUrl,
      data: bytes,
      cancelToken: _cancelToken,
      options: Options(
        headers: {
          "Content-Type": "application/octet-stream",
        },
      ),
      onSendProgress: (sent, total) {
        if (total > 0) {
          onProgress(sent / total);
        }
      },
    );

    AppLogger.log("📦 UPLOAD RESPONSE CODE: ${response.statusCode}");
    AppLogger.log("📦 UPLOAD RESPONSE: ${response.data}");

    return uploadId;
  }

  // ---------------- PLAYBACK POLLING ----------------
  Future<String> getPlaybackId(String mediaId) async {
    final auth = "Basic ${base64Encode(utf8.encode('$tokenId:$secretKey'))}";

    for (int i = 0; i < 120; i++) {
      AppLogger.log("🔄 Poll attempt $i");

      try {
        final response = await dio.get(
          "https://api.fastpix.io/v1/on-demand/$mediaId",
          options: Options(
            headers: {
              "Authorization": auth,
            },
          ),
        );

        AppLogger.log("📦 RESPONSE DATA: ${response.data}");

        final res = response.data;

        if (res is Map && res["data"] != null) {
          final data = res["data"];

          final status = data["status"];
          final playbackIds = data["playbackIds"];

          AppLogger.log("📡 STATUS: $status");

          if (playbackIds is List && playbackIds.isNotEmpty) {
            final playbackId = playbackIds[0]["id"];

            if (status == "Ready") {
              AppLogger.log("✅ PLAYBACK READY: $playbackId");
              return playbackId;
            }
          }
        }
      } catch (e) {
        AppLogger.log("❌ Poll error: $e");
      }

      await Future.delayed(const Duration(seconds: 3));
    }

    throw Exception("Playback not ready after timeout");
  }

  // ---------------- CONTROL METHODS ----------------

  void pause() {
    AppLogger.log("⏸ Upload paused (canceled current request)");
    _isPaused = true;
    _cancelToken?.cancel("paused");

    // NOTE: true resume is NOT supported for signed PUT uploads
    // You must restart upload
  }

  Future<void> resume(Function(double progress) onProgress) async {
    if (_lastFile == null) {
      AppLogger.log("❌ Nothing to resume");
      return;
    }

    AppLogger.log("▶ Resuming upload (restart from beginning)");

    await uploadFile(
      filePath: _lastFile!.path,
      onProgress: onProgress,
    );
  }

  void abort() {
    AppLogger.log("🛑 Upload aborted permanently");

    _isPaused = false;
    _cancelToken?.cancel("aborted");

    _lastFile = null;
    _lastUploadUrl = null;
    _lastUploadId = null;
  }
}
