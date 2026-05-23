import 'package:flutter/foundation.dart';
class AppLogger {
  static void log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}
