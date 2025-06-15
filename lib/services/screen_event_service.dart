import 'package:flutter/services.dart';

class ScreenEventService {
  static const MethodChannel _channel =
      MethodChannel('com.example.neighborhood_connect/screen_events');

  // Check if screen event monitoring is enabled
  static Future<bool> isScreenEventEnabled() async {
    try {
      final bool isEnabled =
          await _channel.invokeMethod('isScreenEventEnabled');
      return isEnabled;
    } on PlatformException catch (e) {
      print("Failed to get screen event status: ${e.message}");
      return false;
    }
  }

  // Toggle screen event monitoring
  static Future<void> toggleScreenEvent(bool enable) async {
    try {
      await _channel.invokeMethod('toggleScreenEvent', {"enable": enable});
      print("Screen event monitoring toggled: $enable");
    } on PlatformException catch (e) {
      print("Failed to toggle screen event: ${e.message}");
    }
  }
}
