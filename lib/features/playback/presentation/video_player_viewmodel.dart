import 'package:flutter/material.dart';

class PlaybackViewModel extends ChangeNotifier {
  String? playbackId;

  bool isLoading = false;

  void setPlaybackId(String id) {
    playbackId = id;
    notifyListeners();
  }
}
