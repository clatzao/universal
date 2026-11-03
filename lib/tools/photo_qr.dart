import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

import '../core/net.dart';

class PhotoFormatError implements Exception {}

class PhotoUploadError implements Exception {}

/// Prazos aceitos pela hospedagem, em horas.
const photoLifetimes = [1, 12, 24, 72];

const photoHostName = 'litterbox.catbox.moe';

/// Hospeda a foto por tempo limitado, para que um QR code possa levar até ela.
class PhotoHost {
  final http.Client? client;

  const PhotoHost({this.client});

  static const maxSide = 1600;

  /// Reduz a foto e a regrava como PNG, o que descarta os metadados, como o local onde foi tirada.
  Future<Uint8List> prepare(Uint8List bytes) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final scale = min(1.0, maxSide / max(descriptor.width, descriptor.height));
      final codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).round(),
        targetHeight: (descriptor.height * scale).round(),
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
      if (data == null) throw PhotoFormatError();
      return data.buffer.asUint8List();
    } on PhotoFormatError {
      rethrow;
    } catch (_) {
      throw PhotoFormatError();
    }
  }

  Future<Uri> upload(Uint8List png, int hours) async {
    final request = http.MultipartRequest('POST', Uri.https(photoHostName, '/resources/internals/api.php'))
      ..headers['User-Agent'] = userAgent
      ..fields['reqtype'] = 'fileupload'
      ..fields['time'] = '${hours}h'
      ..files.add(http.MultipartFile.fromBytes('fileToUpload', png, filename: 'foto.png'));
    try {
      final response = await http.Response.fromStream(
        await (client ?? Net.client).send(request).timeout(const Duration(minutes: 2)),
      ).timeout(const Duration(minutes: 2));
      final link = Uri.tryParse(response.body.trim());
      // Só um endereço da própria hospedagem vai para o QR code.
      if (response.statusCode != 200 || link == null || !link.isScheme('https') || !link.host.endsWith('.catbox.moe')) {
        throw PhotoUploadError();
      }
      return link;
    } on PhotoUploadError {
      rethrow;
    } catch (_) {
      throw PhotoUploadError();
    }
  }
}
