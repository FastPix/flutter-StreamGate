import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/app_di.dart';
import '../../../core/utils/app_logger.dart';

import '../presentation/upload_viewmodel.dart';
import '../presentation/upload_state.dart';

import '../../playback/presentation/video_player_screen.dart';
import '../../record/presentation/record_screen.dart';

class UploadScreen extends StatefulWidget {
  final String? filePath;

  const UploadScreen({
    super.key,
    this.filePath,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  late final UploadViewModel viewModel;

  bool _hasAutoTriggered = false;

  @override
  void initState() {
    super.initState();

    viewModel = UploadViewModel(AppDI.fastPixEngine);

    viewModel.addListener(() {
      if (mounted) setState(() {});
    });

    AppLogger.log(" UploadScreen INIT");
    AppLogger.log("Received filePath: ${widget.filePath}");

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAutoUpload();
    });
  }

  void _triggerAutoUpload() {
    if (_hasAutoTriggered) return;
    _hasAutoTriggered = true;

    final path = widget.filePath;

    if (path == null || path.isEmpty) {
      AppLogger.log("No filePath received — upload skipped");
      return;
    }

    AppLogger.log(" Auto upload triggered");
    AppLogger.log(" File: $path");

    viewModel.uploadVideo(path);
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  Future<void> pickVideo() async {
    try {
      final picker = ImagePicker();

      final file = await picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (file == null) return;

      await viewModel.uploadVideo(file.path);
    } catch (e) {
      AppLogger.log("PICK VIDEO ERROR: $e");
    }
  }

  Widget buildBody() {
    AppLogger.log("UI STATUS: ${viewModel.status}");
    AppLogger.log("Progress: ${viewModel.progress}");

    switch (viewModel.status) {
      case UploadStatus.idle:
        return Center(
          child: ElevatedButton(
            onPressed: pickVideo,
            child: const Text("Pick Video"),
          ),
        );

      case UploadStatus.picking:
        return const Center(child: CircularProgressIndicator());

      case UploadStatus.processing:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Processing video..."),
              SizedBox(height: 8),
              Text("This may take a few seconds"),
            ],
          ),
        );

      case UploadStatus.uploading:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Uploading Video...",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LinearProgressIndicator(
                  value: viewModel.progress,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "${(viewModel.progress * 100).toStringAsFixed(0)}%",
              ),
            ],
          ),
        );

      case UploadStatus.success:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 20),
              const Text(
                "Video Uploaded!",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Playback ID:\n${viewModel.playbackId}",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (viewModel.playbackId == null) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerScreen(
                        playbackId: viewModel.playbackId!,
                      ),
                    ),
                  );
                },
                child: const Text("Play Video"),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text("Go Home"),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RecordScreen(),
                    ),
                  );
                },
                child: const Text("Record New Video"),
              ),
            ],
          ),
        );

      case UploadStatus.failed:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 80),
              const SizedBox(height: 20),
              const Text(
                "Upload Failed",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  viewModel.errorMessage ?? "Unknown Error",
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: pickVideo,
                child: const Text("Retry"),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Video"),
      ),
      body: buildBody(),
    );
  }
}
