import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../photon_romagna.dart';
import 'percorso_walk.dart';

/// Risultato routing a piedi su strada (GraphHopper foot).
class WalkRouteResult {
  const WalkRouteResult({
    required this.meters,
    required this.duration,
    required this.points,
  });

  final double meters;
  final Duration duration;
  final List<LatLng> points;
}

/// Bridge verso GraphHopper nativo (Android). Altrove resta disabilitato.
class GraphHopperWalkService {
  GraphHopperWalkService._();

  static final GraphHopperWalkService instance = GraphHopperWalkService._();

  static const MethodChannel _channel = MethodChannel(
    'com.example.romagnago/graphhopper_walk',
  );

  bool _initialized = false;
  bool _initAttempted = false;

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  bool get isReady => _initialized;

  /// Carica il grafo da asset (prima estrazione in storage interno).
  Future<bool> initialize() async {
    if (!isSupported) return false;
    if (_initialized) return true;
    if (_initAttempted) return false;
    _initAttempted = true;
    try {
      final ok = await _channel.invokeMethod<bool>('initialize');
      _initialized = ok == true;
      if (kDebugMode) {
        debugPrint(
          'GraphHopperWalkService: init ${_initialized ? "ok" : "fallita (asset mancante?)"}',
        );
      }
      return _initialized;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('GraphHopperWalkService.initialize: $e\n$st');
      }
      return false;
    }
  }

  /// Percorso a piedi su strada; `null` se motore non pronto o fuori bbox.
  Future<WalkRouteResult?> routeFoot(LatLng from, LatLng to) async {
    if (!isSupported ||
        !_initialized ||
        !isWithinRomagnaBounds(from) ||
        !isWithinRomagnaBounds(to)) {
      return null;
    }
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'routeFoot',
        {
          'fromLat': from.latitude,
          'fromLon': from.longitude,
          'toLat': to.latitude,
          'toLon': to.longitude,
        },
      );
      if (raw == null) return null;
      final distance = (raw['distanceMeters'] as num?)?.toDouble();
      final timeMs = (raw['timeMs'] as num?)?.toInt();
      final ptsRaw = raw['points'];
      if (distance == null || timeMs == null || ptsRaw is! List) return null;

      final points = <LatLng>[];
      for (final item in ptsRaw) {
        if (item is! Map) continue;
        final lat = (item['lat'] as num?)?.toDouble();
        final lng = (item['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        if (!lat.isFinite || !lng.isFinite) continue;
        points.add(LatLng(lat, lng));
      }
      if (points.length < 2) return null;

      return WalkRouteResult(
        meters: distance,
        duration: Duration(
          milliseconds: timeMs.clamp(1000, 86400000),
        ),
        points: points,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('GraphHopperWalkService.routeFoot: $e\n$st');
      }
      return null;
    }
  }

  /// Stima con GraphHopper se disponibile, altrimenti Haversine.
  Future<({double meters, Duration duration})> walkEstimate(LatLng from, LatLng to) async {
    final routed = await routeFoot(from, to);
    if (routed != null) {
      return (meters: routed.meters, duration: routed.duration);
    }
  return percorsoWalkEstimate(from, to);
  }
}
