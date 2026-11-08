import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class GrowthReminders {
  static const channel = MethodChannel('selah/journey');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static Future<Map<dynamic, dynamic>> status() async {
    if (!supported) return {};
    try {
      return await channel
              .invokeMapMethod<dynamic, dynamic>('reminderStatus') ??
          {};
    } on MissingPluginException {
      return {};
    }
  }

  static Future<bool> configure(bool enabled, int hour, int minute) async =>
      await channel.invokeMethod<bool>(
          'reminder', {'enabled': enabled, 'hour': hour, 'minute': minute}) ??
      false;
}
