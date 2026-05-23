import 'package:flutter/material.dart';

enum RecordingType {
  none,
  camera,
  screen,
}

class RecordViewModel extends ChangeNotifier {
  String? recordedFilePath;
  bool isRecording = false;
  RecordingType recordingType = RecordingType.none;

  // START RECORDING STATE
  void startRecording(RecordingType type) {
    isRecording = true;
    recordingType = type;
    notifyListeners();
  }

  // STOP RECORDING STATE (Bug 4 Fix: Trap path variable mapping gracefully)
  void stopRecording({String? path}) {
    isRecording = false;
    if (path != null) {
      recordedFilePath = path;
    }
    notifyListeners();
  }

  // SET FILE PATH (CAMERA / SCREEN)
  void setFilePath(String path) {
    recordedFilePath = path;
    notifyListeners();
  }

  // RESET ALL STATE
  void reset() {
    recordedFilePath = null;
    isRecording = false;
    recordingType = RecordingType.none;
    notifyListeners();
  }
}