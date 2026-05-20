import 'package:flutter/material.dart';
import 'camera_record_screen.dart';
import 'screen_record_screen.dart';
import '../../upload/presentation/upload_screen.dart';

class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  // 📹 CAMERA FLOW (unchanged, but now consistent)
  void openCamera(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraRecordScreen(),
      ),
    );
  }

  // 📱 SCREEN RECORDING → NOW RETURNS PATH → AUTO UPLOAD
  void openScreenRecorder(BuildContext context) async {
    final path = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ScreenRecordScreen(),
      ),
    );

    // 🚀 IF RECORDING RETURNS FILE PATH → START UPLOAD FLOW
    if (path != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UploadScreen(filePath: path),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Record Video"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 📹 CAMERA RECORDING
            ElevatedButton.icon(
              icon: const Icon(Icons.videocam),
              label: const Text("Record Camera Video"),
              onPressed: () => openCamera(context),
            ),

            const SizedBox(height: 20),

            // 📱 SCREEN RECORDING
            ElevatedButton.icon(
              icon: const Icon(Icons.screen_share),
              label: const Text("Record Screen"),
              onPressed: () => openScreenRecorder(context),
            ),
          ],
        ),
      ),
    );
  }
}
