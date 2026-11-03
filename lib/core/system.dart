import 'package:flutter/services.dart';

/// Recursos do Android que os plugins não expõem (ver MainActivity.kt).
class SystemInfo {
  static const _channel = MethodChannel('universal/system');

  static Future<bool> canUseFullScreenIntent() => _ask('canUseFullScreenIntent');

  static Future<bool> isIgnoringBatteryOptimizations() => _ask('isIgnoringBatteryOptimizations');

  static Future<void> openFullScreenSettings() => _channel.invokeMethod('openFullScreenSettings');

  static Future<void> openBatterySettings() => _channel.invokeMethod('openBatterySettings');

  static Future<bool> _ask(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? true;
    } on PlatformException {
      return true;
    } on MissingPluginException {
      return true;
    }
  }
}
