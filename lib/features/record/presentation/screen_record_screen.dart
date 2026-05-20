import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/record_service.dart';
import 'record_viewmodel.dart';
import '../../upload/presentation/upload_screen.dart';

class ScreenRecordScreen extends StatefulWidget {
  const ScreenRecordScreen({super.key});

  @override
  State<ScreenRecordScreen> createState() => _ScreenRecordScreenState();
}

class _ScreenRecordScreenState extends State<ScreenRecordScreen> {
  late RecordService service;

  @override
  void initState() {
    super.initState();
    service = RecordService();
  }

  // 📱 START SCREEN RECORDING
  Future<void> startRecording(RecordViewModel vm) async {
    vm.startRecording(RecordingType.screen);

    await service.startScreenRecording("streamgate_screen_record");
  }

  // ⏹ STOP SCREEN RECORDING
  Future<void> stopRecording(RecordViewModel vm) async {
    final path = await service.stopScreenRecording();

    vm.stopRecording();

    if (path == null || path.isEmpty) {
      debugPrint("❌ No screen recording file generated");
      return;
    }

    debugPrint("📁 Screen recording saved at: $path");

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => UploadScreen(
          filePath: path,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecordViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Screen Recording"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🎬 STATUS TEXT
            Text(
              vm.isRecording
                  ? "🔴 Recording Screen..."
                  : "Ready to record your screen",
              style: const TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 30),

            // ▶ START BUTTON
            if (!vm.isRecording)
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text("Start Recording"),
                onPressed: () => startRecording(vm),
              ),

            // ⏹ STOP BUTTON
            if (vm.isRecording)
              ElevatedButton.icon(
                icon: const Icon(Icons.stop),
                label: const Text("Stop Recording"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () => stopRecording(vm),
              ),
          ],
        ),
      ),
    );
  }
}
