import 'package:flutter/material.dart';
import 'camera_record_screen.dart';
import 'screen_record_screen.dart';
import '../../upload/presentation/upload_screen.dart';

class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  // CAMERA FLOW 
  void openCamera(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraRecordScreen(),
      ),
    );
  }

  // SCREEN RECORDING (Unified Controller Pathway)
  void openScreenRecorder(BuildContext context) async {
    //  Fixed Navigation Conflict: Await path from pop, do not push Upload from child screen
    final String? path = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const ScreenRecordScreen(),
      ),
    );

    // IF RECORDING RETURNS FILE PATH -> START UPLOAD FLOW
    if (path != null && path.isNotEmpty && context.mounted) {
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
            // CAMERA RECORDING
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.videocam),
                label: const Text("Record Camera Video"),
                onPressed: () => openCamera(context),
              ),
            ),
            const SizedBox(height: 20),

            //  SCREEN RECORDING
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.screen_share),
                label: const Text("Record Screen"),
                onPressed: () => openScreenRecorder(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}