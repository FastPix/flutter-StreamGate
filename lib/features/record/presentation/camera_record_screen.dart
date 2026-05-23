import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../upload/presentation/upload_screen.dart';

class CameraRecordScreen extends StatefulWidget {
  const CameraRecordScreen({super.key});

  @override
  State<CameraRecordScreen> createState() => _CameraRecordScreenState();
}
class _CameraRecordScreenState extends State<CameraRecordScreen> {
  CameraController? controller;
  List<CameraDescription>? cameras;

  XFile? recordedFile;

  bool isRecording = false;

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    cameras = await availableCameras();

    controller = CameraController(
      cameras!.first,
      ResolutionPreset.low,
    );

    await controller!.initialize();
    setState(() {});
  }

  Future<void> startRecording() async {
    await controller!.startVideoRecording();
    setState(() => isRecording = true);
  }

  Future<void> stopRecording() async {
    final file = await controller!.stopVideoRecording();

    setState(() {
      isRecording = false;
      recordedFile = file;
    });

    // AUTO GO TO UPLOAD FLOW

    final filePath = recordedFile!.path;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => UploadScreen(
          filePath: filePath,
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Camera")),
      body: Stack(
        children: [
          CameraPreview(controller!),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                backgroundColor: isRecording ? Colors.red : Colors.white,
                onPressed: () {
                  if (isRecording) {
                    stopRecording();
                  } else {
                    startRecording();
                  }
                },
                child: Icon(
                  isRecording ? Icons.stop : Icons.circle,
                  color: Colors.black,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
