import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../core/json_store.dart';
import '../settings/settings.dart';
import 'quotes.dart';
import 'weather.dart';

/// Posição atual (se permitido), com reserva na última conhecida.
Future<Position?> currentPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    final p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 20)),
      );
    } catch (_) {
      return await Geolocator.getLastKnownPosition();
    }
  } catch (_) {
    return null;
  }
}

class InfoStore extends ChangeNotifier {
  final SettingsStore settings;
  Weather? weather;
  Quotes? quotes;
  bool loading = false;
  String? error;

  InfoStore(this.settings);

  Future<void> load() async {
    final c = await JsonStore.read('info_cache');
    if (c is Map) {
      try {
        if (c['weather'] != null) weather = Weather.fromJson((c['weather'] as Map).cast<String, dynamic>());
        if (c['quotes'] != null) quotes = Quotes.fromJson((c['quotes'] as Map).cast<String, dynamic>());
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _persist() => JsonStore.write('info_cache', {
        'weather': weather?.toJson(),
        'quotes': quotes?.toJson(),
      });

  Future<void> refresh({bool force = false}) async {
    if (loading) return;
    final fresh = DateTime.now().subtract(const Duration(minutes: 20));
    if (!force &&
        weather != null &&
        quotes != null &&
        weather!.fetchedAt.isAfter(fresh) &&
        quotes!.fetchedAt.isAfter(fresh)) {
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    final s = settings.value;
    try {
      double? lat = s.lat, lon = s.lon;
      if (s.useGps) {
        final p = await currentPosition();
        if (p != null) {
          lat = p.latitude;
          lon = p.longitude;
        }
      }
      Future<void> q() async {
        try {
          quotes = await Quotes.fetch();
        } catch (_) {}
      }

      Future<void> w() async {
        if (lat == null || lon == null) return;
        try {
          weather = await Weather.fetch(lat, lon);
        } catch (_) {
          error = 'Clima indisponível';
        }
      }

      await Future.wait([q(), w()]);
      await _persist();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
