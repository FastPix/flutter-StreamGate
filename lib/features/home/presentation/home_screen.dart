import 'package:flutter/material.dart';

import '../../upload/presentation/upload_screen.dart';
import '../../record/presentation/record_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void openUpload(
    BuildContext context,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const UploadScreen(),
      ),
    );
  }

  Future<void> openRecord(
    BuildContext context,
  ) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RecordScreen(),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "StreamGate",
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.video_collection,
                size: 80,
              ),
              const SizedBox(
                height: 24,
              ),
              const Text(
                "StreamGate",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 12,
              ),
              const Text(
                "Upload and share videos instantly",
                textAlign: TextAlign.center,
              ),
              const SizedBox(
                height: 40,
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => openUpload(context),
                  icon: const Icon(
                    Icons.upload,
                  ),
                  label: const Text(
                    "Upload Video",
                  ),
                ),
              ),
              const SizedBox(
                height: 16,
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => openRecord(context),
                  icon: const Icon(
                    Icons.videocam,
                  ),
                  label: const Text(
                    "Record Video",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
