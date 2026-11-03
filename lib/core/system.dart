import 'package:flutter/services.dart';

/// Recursos do Android que os plugins não expõem (ver MainActivity.kt).
class SystemInfo {
  static const _channel = MethodChannel('universal/system');

  static Future<bool> canUseFullScreenIntent() => _ask('canUseFullScreenIntent');

  static Future<bool> isIgnoringBatteryOptimizations() => _ask('isIgnoringBatteryOptimizations');

  static Future<void> openFullScreenSettings() => _channel.invokeMethod('openFullScreenSettings');

  static Future<void> openBatterySettings() => _channel.invokeMethod('openBatterySettings');

  /// Impede capturas de tela e esconde a prévia do app na lista de recentes.
  static Future<void> setSecure(bool secure) async {
    try {
      await _channel.invokeMethod('setSecure', secure);
    } on PlatformException {
      // Sem a proteção de tela o cofre continua funcionando.
    } on MissingPluginException {
      // Idem, fora do Android.
    }
  }

  /// Abre o seletor de arquivos do Android para salvar. Retorna false se a pessoa cancelar.
  static Future<bool> saveFile(String name, List<int> bytes, {String type = 'application/octet-stream'}) async =>
      await _channel.invokeMethod<bool>('saveFile', {'name': name, 'bytes': Uint8List.fromList(bytes), 'type': type}) ??
      false;

  /// Abre o seletor de arquivos do Android. Retorna null se a pessoa cancelar.
  static Future<Uint8List?> openFile({String type = '*/*'}) =>
      _channel.invokeMethod<Uint8List>('openFile', {'type': type});

  /// Atalho do ícone que abriu o app, se houver.
  static Future<String?> takeShortcut() async {
    try {
      return await _channel.invokeMethod<String>('takeShortcut');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Atalhos usados com o app já aberto.
  static void listenShortcuts(void Function(String name) onShortcut) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shortcut' && call.arguments is String) onShortcut(call.arguments as String);
    });
  }

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
