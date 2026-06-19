import 'package:latlong2/latlong.dart';

import 'percorso_constants.dart';

const Distance _distance = Distance();

/// Distanza e durata a piedi (Haversine × fattore deviazione).
({double meters, Duration duration}) percorsoWalkEstimate(
  LatLng from,
  LatLng to,
) {
  final raw = _distance.as(LengthUnit.Meter, from, to);
  final meters = raw * PercorsoConstants.walkDetourFactor;
  final seconds = meters / PercorsoConstants.walkSpeedMps;
  return (
    meters: meters,
    duration: Duration(seconds: seconds.round().clamp(1, 86400)),
  );
}

String percorsoFormatWalkDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}
