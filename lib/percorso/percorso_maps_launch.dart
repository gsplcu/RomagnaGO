import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Apre Google Maps / Apple Mappe con navigazione pedonale A→B.
Future<bool> launchWalkingTurnByTurn({
  required LatLng from,
  required LatLng to,
}) async {
  if (!from.latitude.isFinite ||
      !from.longitude.isFinite ||
      !to.latitude.isFinite ||
      !to.longitude.isFinite) {
    return false;
  }

  final origin = '${from.latitude},${from.longitude}';
  final dest = '${to.latitude},${to.longitude}';

  final candidates = <Uri>[
    if (!kIsWeb && Platform.isIOS)
      Uri.parse(
        'http://maps.apple.com/?saddr=$origin&daddr=$dest&dirflg=w',
      ),
    Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=$origin&destination=$dest&travelmode=walking',
    ),
    Uri.parse('google.navigation:q=$dest&mode=w'),
  ];

  for (final uri in candidates) {
    try {
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return true;
      }
    } catch (_) {
      continue;
    }
  }
  return false;
}
