/// Contenuti da [Start Romagna – Navetta Cesenatico](https://www.startromagna.it/navetta-cesenatico/).
library;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'start_content/navetta_content_sync.dart';
import 'start_content/start_content_id.dart';

/// Tile Humanitarian OSM (stesso layer predefinito mappa principale).
const kNavettaCesenaticoOsmHotTileUrl =
    'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';
const kNavettaCesenaticoOsmHotSubdomains = ['a', 'b', 'c'];

class NavettaCesenaticoMapStop {
  const NavettaCesenaticoMapStop({
    required this.displayName,
    required this.roleLabel,
    required this.point,
  });

  final String displayName;
  final String roleLabel;
  final LatLng point;
}

/// Fermate navetta Cesenatico (ordine percorso andata/ritorno).
const kNavettaCesenaticoMapStops = [
  NavettaCesenaticoMapStop(
    displayName: 'Parcheggio Cimitero',
    roleLabel: 'Capolinea',
    point: LatLng(44.20575811292511, 12.388519068476837),
  ),
  NavettaCesenaticoMapStop(
    displayName: 'Atlantica',
    roleLabel: 'Andata',
    point: LatLng(44.21152168619593, 12.388710618544446),
  ),
  NavettaCesenaticoMapStop(
    displayName: 'De Varthema',
    roleLabel: 'Andata',
    point: LatLng(44.21535666971264, 12.387248034467962),
  ),
  NavettaCesenaticoMapStop(
    displayName: 'Diaz',
    roleLabel: 'Andata',
    point: LatLng(44.21867569856016, 12.384610408604605),
  ),
  NavettaCesenaticoMapStop(
    displayName: 'De Varthema',
    roleLabel: 'Ritorno',
    point: LatLng(44.21456067441028, 12.387839695184384),
  ),
  NavettaCesenaticoMapStop(
    displayName: 'Atlantica',
    roleLabel: 'Ritorno',
    point: LatLng(44.2117541768743, 12.388461529661793),
  ),
];

List<LatLng> get kNavettaCesenaticoRoutePoints =>
    kNavettaCesenaticoMapStops.map((stop) => stop.point).toList();

/// Rettangolo da punti GPX/fermate con padding opzionale (gradi decimali).
({LatLng southWest, LatLng northEast}) boundsFromRoutePoints(
  List<LatLng> points, {
  double paddingDegrees = 0.003,
}) {
  var south = points.first.latitude;
  var north = points.first.latitude;
  var west = points.first.longitude;
  var east = points.first.longitude;
  for (final p in points) {
    if (p.latitude < south) south = p.latitude;
    if (p.latitude > north) north = p.latitude;
    if (p.longitude < west) west = p.longitude;
    if (p.longitude > east) east = p.longitude;
  }
  return (
    southWest: LatLng(south - paddingDegrees, west - paddingDegrees),
    northEast: LatLng(north + paddingDegrees, east + paddingDegrees),
  );
}

/// Bounding box area di servizio (padding ~250 m ai bordi).
({LatLng southWest, LatLng northEast}) navettaCesenaticoServiceBounds({
  double paddingDegrees = 0.0025,
}) {
  return boundsFromRoutePoints(
    kNavettaCesenaticoRoutePoints,
    paddingDegrees: paddingDegrees,
  );
}

/// Palette pagina parcheggio/navetta (tema verde Start Romagna).
abstract final class NavettaCesenaticoColors {
  static const green = Color(0xFF16724F);
  static const greenDark = Color(0xFF0F5138);
  static const greenSoft = Color(0xFFEEF8F3);
  static const greenLine = Color(0xFFB8DECF);
  static const text = Color(0xFF1F2937);
}

const kNavettaCesenaticoMapAsset =
    'assets/Navetta-Cesenatico-parcheggio-1.png';

const kNavettaCesenaticoGpxAsset = 'assets/navetta_cesenatico_gpx.gpx';

class NavettaCesenaticoFeature {
  const NavettaCesenaticoFeature({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;
}

const _kNavettaCesenaticoFeatureIcons = [
  Icons.local_parking_rounded,
  Icons.airport_shuttle_rounded,
  Icons.beach_access_rounded,
];

const _kNavettaCesenaticoFeaturesStatic = [
  NavettaCesenaticoFeature(
    title: '400 posti auto',
    body:
        'Grande parcheggio gratuito realizzato in materiale permeabile con oltre 90 nuove piantumazioni.',
    icon: Icons.local_parking_rounded,
  ),
  NavettaCesenaticoFeature(
    title: 'Servizio navetta',
    body:
        'Collegamento gratuito con Atlantica, via De Varthema e via Diaz fino al lungomare.',
    icon: Icons.airport_shuttle_rounded,
  ),
  NavettaCesenaticoFeature(
    title: 'Vicino al mare',
    body:
        'Collegamento rapido verso Ponente grazie al percorso ciclo-pedonale e alla navetta dedicata.',
    icon: Icons.beach_access_rounded,
  ),
];

List<NavettaCesenaticoFeature> get kNavettaCesenaticoFeatures {
  final synced = NavettaContentSync.mapList(
    StartContentId.navettaCesenatico,
    'features',
  );
  if (synced.isEmpty) return _kNavettaCesenaticoFeaturesStatic;
  return [
    for (var i = 0; i < synced.length; i++)
      NavettaCesenaticoFeature(
        title: '${synced[i]['title'] ?? ''}',
        body: '${synced[i]['body'] ?? ''}',
        icon: i < _kNavettaCesenaticoFeatureIcons.length
            ? _kNavettaCesenaticoFeatureIcons[i]
            : Icons.info_outline_rounded,
      ),
  ];
}

class NavettaCesenaticoHelpLink {
  const NavettaCesenaticoHelpLink({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.uri,
    this.opensContattiPage = false,
  }) : assert(uri != null || opensContattiPage);

  final String title;
  final String subtitle;
  final Uri? uri;
  final IconData icon;
  final bool opensContattiPage;
}

final kNavettaCesenaticoHelpLinks = [
  NavettaCesenaticoHelpLink(
    title: 'Telefono',
    subtitle: '199.11.55.77',
    uri: Uri(scheme: 'tel', path: '199115577'),
    icon: Icons.phone_rounded,
  ),
  NavettaCesenaticoHelpLink(
    title: 'WhatsApp',
    subtitle: 'Chatta con noi',
    uri: Uri.parse('https://wa.me/393316566555'),
    icon: Icons.chat_rounded,
  ),
  NavettaCesenaticoHelpLink(
    title: 'Servizio Clienti',
    subtitle: 'Vai ai contatti',
    icon: Icons.support_agent_rounded,
    opensContattiPage: true,
  ),
];

class NavettaStopPassage {
  const NavettaStopPassage({
    required this.stopName,
    required this.time,
    required this.directionLabel,
  });

  final String stopName;
  final String time;
  final String directionLabel;
}

class NavettaShuttleRun {
  const NavettaShuttleRun({
    required this.departureTime,
    required this.passages,
  });

  final String departureTime;
  final List<NavettaStopPassage> passages;
}

/// Fermate lungo il percorso (andata + ritorno).
const _kRouteStops = [
  ('Parcheggio Cimitero', 'Partenza'),
  ('Atlantica', 'Andata'),
  ('De Varthema', 'Andata'),
  ('Diaz', 'Andata'),
  ('De Varthema', 'Ritorno'),
  ('Atlantica', 'Ritorno'),
  ('Parcheggio Cimitero', 'Arrivo'),
];

const _kScheduleRows = [
  [
    '08:30', '08:50', '09:10', '09:30', '09:50', '10:10', '10:30', '10:50',
    '11:10', '11:30', '11:50', '14:00', '14:20', '14:40', '15:00', '15:20',
    '15:40', '16:00', '16:20', '16:40', '17:00', '17:20', '17:40', '18:00',
    '18:20', '18:40',
  ],
  [
    '08:33', '08:53', '09:13', '09:33', '09:53', '10:13', '10:33', '10:53',
    '11:13', '11:33', '11:53', '14:03', '14:23', '14:43', '15:03', '15:23',
    '15:43', '16:03', '16:23', '16:43', '17:03', '17:23', '17:43', '18:03',
    '18:23', '18:43',
  ],
  [
    '08:35', '08:55', '09:15', '09:35', '09:55', '10:15', '10:35', '10:55',
    '11:15', '11:35', '11:55', '14:05', '14:25', '14:45', '15:05', '15:25',
    '15:45', '16:05', '16:25', '16:45', '17:05', '17:25', '17:45', '18:05',
    '18:25', '18:45',
  ],
  [
    '08:36', '08:56', '09:16', '09:36', '09:56', '10:16', '10:36', '10:56',
    '11:16', '11:36', '11:56', '14:06', '14:26', '14:46', '15:06', '15:26',
    '15:46', '16:06', '16:26', '16:46', '17:06', '17:26', '17:46', '18:06',
    '18:26', '18:46',
  ],
  [
    '08:38', '08:58', '09:18', '09:38', '09:58', '10:18', '10:38', '10:58',
    '11:18', '11:38', '11:58', '14:08', '14:28', '14:48', '15:08', '15:28',
    '15:48', '16:08', '16:28', '16:48', '17:08', '17:28', '17:48', '18:08',
    '18:28', '18:48',
  ],
  [
    '08:40', '09:00', '09:20', '09:40', '10:00', '10:20', '10:40', '11:00',
    '11:20', '11:40', '12:00', '14:10', '14:30', '14:50', '15:10', '15:30',
    '15:50', '16:10', '16:30', '16:50', '17:10', '17:30', '17:50', '18:10',
    '18:30', '18:50',
  ],
  [
    '08:43', '09:03', '09:23', '09:43', '10:03', '10:23', '10:43', '11:03',
    '11:23', '11:43', '12:03', '14:13', '14:33', '14:53', '15:13', '15:33',
    '15:53', '16:13', '16:33', '16:53', '17:13', '17:33', '17:53', '18:13',
    '18:33', '18:53',
  ],
];

List<NavettaShuttleRun> buildNavettaCesenaticoRuns() {
  final runCount = _kScheduleRows.first.length;
  final runs = <NavettaShuttleRun>[];
  for (var i = 0; i < runCount; i++) {
    final passages = <NavettaStopPassage>[];
    for (var r = 0; r < _kRouteStops.length; r++) {
      final stop = _kRouteStops[r];
      passages.add(
        NavettaStopPassage(
          stopName: stop.$1,
          directionLabel: stop.$2,
          time: _kScheduleRows[r][i],
        ),
      );
    }
    runs.add(
      NavettaShuttleRun(
        departureTime: passages.first.time,
        passages: passages,
      ),
    );
  }
  return runs;
}

/// Fermate selezionabili per la vista «Per fermata».
const kNavettaCesenaticoStopFilters = [
  'Parcheggio Cimitero',
  'Atlantica',
  'De Varthema',
  'Diaz',
];

List<NavettaStopPassage> navettaPassagesForStop(String stopName) {
  final out = <NavettaStopPassage>[];
  for (final run in buildNavettaCesenaticoRuns()) {
    for (final p in run.passages) {
      if (p.stopName == stopName) out.add(p);
    }
  }
  out.sort((a, b) => _timeSortKey(a.time).compareTo(_timeSortKey(b.time)));
  return out;
}

int _timeSortKey(String hm) {
  final parts = hm.split(':');
  if (parts.length != 2) return 0;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  return h * 60 + m;
}

bool navettaTimeIsMorning(String hm) => _timeSortKey(hm) < 12 * 60;
