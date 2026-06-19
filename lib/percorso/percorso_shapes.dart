import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../linee_percorsi.dart';
import '../transit_stops.dart';
import 'percorso_index.dart';

/// Tratti di linea da GPX in [assets/shapes] per la mappa dettaglio Percorso.
abstract final class PercorsoShapeCache {
  static final Map<String, _ShapeAssetRecord> _shapeAssetCache = {};
  static final Map<String, List<LatLng>> _fullLineCache = {};
  static Map<String, LatLng>? _stopsByIdCache;
  static Future<Map<String, LatLng>>? _stopsByIdLoading;
  static final Map<String, Map<String, Set<String>>> _shapeDeparturesCache = {};

  /// Ancoraggio fermata→shape: oltre questa distanza non si forza il punto GPX
  /// (evita corde rettilinee verso capolinea/fermate lontane dal tracciato).
  static const double _maxStopAnchorGapMeters = 220;

  /// Scarta slice con corda iniziale/finale troppo lunga.
  static const double _maxEndpointChordMeters = 300;

  /// Due shape in catena (es. Gatteo→Cesenatico + Cesenatico→Zadina).
  static const double _maxChainJointGapMeters = 650;

  static Future<List<LatLng>> pointsForRideLeg({
    required String routeKey,
    required LatLng from,
    required LatLng to,
    String? tripId,
    String? boardStopId,
    String? alightStopId,
  }) async {
    if (!_isFinite(from) || !_isFinite(to)) {
      return _finiteOnly([from, to]);
    }

    final parts = routeKey.split('|');
    if (parts.length < 2) return _finiteOnly([from, to]);
    final basin = parts[0].trim();
    final routeId = parts[1].trim();
    if (basin.isEmpty || routeId.isEmpty) return _finiteOnly([from, to]);

    final assets = await _assetsForLeg(
      basin: basin,
      routeId: routeId,
      tripId: tripId,
      boardStopId: boardStopId,
      alightStopId: alightStopId,
    );
    if (assets.isEmpty) return _finiteOnly([from, to]);

    final stopMap = await _loadStopsById();
    final boardPoint = _resolveStopPoint(stopMap, boardStopId, from);
    final alightPoint = _resolveStopPoint(stopMap, alightStopId, to);

    final depKey = await _tripDepartureKey(
      tripId: tripId,
      boardStopId: boardStopId,
    );
    final departuresByShape = await _loadDeparturesByShape(
      basin: basin,
      routeId: _shapeRouteAlias(basin, routeId),
    );

    var bestPick = await _pickBestShapeSubslice(
      assets: assets,
      boardPoint: boardPoint,
      alightPoint: alightPoint,
      departuresByShape: departuresByShape,
      depKey: depKey,
      tripId: tripId,
      boardStopId: boardStopId,
      alightStopId: alightStopId,
    );

    if (bestPick == null) {
      bestPick = await _tryChainedShapeSubslice(
        assets: assets,
        boardPoint: boardPoint,
        alightPoint: alightPoint,
        departuresByShape: departuresByShape,
        depKey: depKey,
        tripId: tripId,
        boardStopId: boardStopId,
        alightStopId: alightStopId,
      );
    }

    if (bestPick == null) {
      return _finiteOnly([boardPoint, alightPoint]);
    }
    return bestPick.points;
  }

  /// Cicla gli shape GPX gemelli della linea e sceglie il sotto-tracciato migliore.
  static Future<_ShapeSlicePick?> _pickBestShapeSubslice({
    required List<String> assets,
    required LatLng boardPoint,
    required LatLng alightPoint,
    required Map<String, Set<String>> departuresByShape,
    required String? depKey,
    String? tripId,
    String? boardStopId,
    String? alightStopId,
  }) async {
    final stopMap = await _loadStopsById();
    _ShapeSlicePick? bestPick;
    for (final asset in assets) {
      final record = await _loadShapeAssetRecord(asset);
      final slice = _sliceShapeSegment(
        shapePoints: record.points,
        fermataA: boardPoint,
        fermataB: alightPoint,
      );
      if (slice == null || slice.points.length < 2) continue;

      final segment = slice.points;
      if (!_segmentFollowsTravelDirection(segment, boardPoint, alightPoint)) {
        continue;
      }

      final direct = _distanceMeters(boardPoint, alightPoint);
      final slicedLength = _polylineLengthMeters(segment);
      final boardGap = slice.boardGapMeters;
      final alightGap = slice.alightGapMeters;
      final microOnShape = _isMicroShapeSlice(
        directMeters: direct,
        slicedLengthMeters: slicedLength,
        boardGapMeters: boardGap,
        alightGapMeters: alightGap,
      );
      if (!microOnShape) {
        if (!_isLengthCompatible(direct, slicedLength)) continue;
      }

      if (boardGap > _maxStopAnchorGapMeters * 1.6 ||
          alightGap > _maxStopAnchorGapMeters * 1.6) {
        continue;
      }
      if (direct < 700) {
        final compactSlice = slicedLength < direct * 0.85;
        final maxGap =
            compactSlice ? _maxStopAnchorGapMeters * 1.35 : _maxStopAnchorGapMeters;
        if (boardGap > maxGap || alightGap > maxGap) continue;
      }
      if (_endpointChordTooLong(segment)) continue;

      if (tripId != null && boardStopId != null && alightStopId != null) {
        final okOrder = await _shapeSupportsTripStopOrder(
          shapePoints: record.points,
          tripId: tripId,
          boardStopId: boardStopId,
          alightStopId: alightStopId,
          stopMap: stopMap,
        );
        if (!okOrder) continue;
      }

      final score = _shapeScore(
        shapeId: record.shapeId,
        departuresByShape: departuresByShape,
        depKey: depKey,
        boardGapMeters: boardGap,
        alightGapMeters: alightGap,
        slicedLengthMeters: slicedLength,
        maxSegmentMeters: _maxSegmentMeters(segment),
        directMeters: direct,
      );

      final pick = _ShapeSlicePick(points: segment, score: score);
      if (bestPick == null || pick.score < bestPick.score) {
        bestPick = pick;
      }
    }
    return bestPick;
  }

  /// Due GPX contigui (stesso corridoio, varianti direzione diverse).
  static Future<_ShapeSlicePick?> _tryChainedShapeSubslice({
    required List<String> assets,
    required LatLng boardPoint,
    required LatLng alightPoint,
    required Map<String, Set<String>> departuresByShape,
    required String? depKey,
    String? tripId,
    String? boardStopId,
    String? alightStopId,
  }) async {
    final stopMap = await _loadStopsById();
    final records = <_ShapeAssetRecord>[];
    for (final asset in assets) {
      records.add(await _loadShapeAssetRecord(asset));
    }

    _ShapeSlicePick? bestPick;
    for (var i = 0; i < records.length; i++) {
      for (var j = 0; j < records.length; j++) {
        if (i == j) continue;
        final head = records[i];
        final tail = records[j];
        final headSlice = _sliceShapeSegment(
          shapePoints: head.points,
          fermataA: boardPoint,
          fermataB: head.points.last,
        );
        final tailSlice = _sliceShapeSegment(
          shapePoints: tail.points,
          fermataA: tail.points.first,
          fermataB: alightPoint,
        );
        if (headSlice == null ||
            tailSlice == null ||
            headSlice.points.length < 2 ||
            tailSlice.points.length < 2) {
          continue;
        }

        final jointGap = _distanceMeters(
          headSlice.points.last,
          tailSlice.points.first,
        );
        if (jointGap > _maxChainJointGapMeters) continue;

        final merged = <LatLng>[
          ...headSlice.points,
          ...tailSlice.points.skip(1),
        ];
        if (!_segmentFollowsTravelDirection(merged, boardPoint, alightPoint)) {
          continue;
        }

        final direct = _distanceMeters(boardPoint, alightPoint);
        final slicedLength = _polylineLengthMeters(merged);
        if (!_isLengthCompatible(direct, slicedLength)) continue;
        if (_endpointChordTooLong(merged)) continue;

        if (tripId != null && boardStopId != null && alightStopId != null) {
          final okHead = await _shapeSupportsTripStopOrder(
            shapePoints: head.points,
            tripId: tripId,
            boardStopId: boardStopId,
            alightStopId: alightStopId,
            stopMap: stopMap,
          );
          final okTail = await _shapeSupportsTripStopOrder(
            shapePoints: tail.points,
            tripId: tripId,
            boardStopId: boardStopId,
            alightStopId: alightStopId,
            stopMap: stopMap,
          );
          if (!okHead && !okTail) continue;
        }

        final score = _shapeScore(
          shapeId: head.shapeId,
          departuresByShape: departuresByShape,
          depKey: depKey,
          boardGapMeters: headSlice.boardGapMeters,
          alightGapMeters: tailSlice.alightGapMeters,
          slicedLengthMeters: slicedLength,
          maxSegmentMeters: _maxSegmentMeters(merged),
          directMeters: direct,
        ) +
            jointGap * 2.0;

        final pick = _ShapeSlicePick(points: merged, score: score);
        if (bestPick == null || pick.score < bestPick.score) {
          bestPick = pick;
        }
      }
    }
    return bestPick;
  }

  static List<LatLng> extractShapeSegment({
    required List<LatLng> shapePoints,
    required LatLng fermataA,
    required LatLng fermataB,
  }) {
    final slice = _sliceShapeSegment(
      shapePoints: shapePoints,
      fermataA: fermataA,
      fermataB: fermataB,
    );
    if (slice == null) return [fermataA, fermataB];
    return slice.points;
  }

  static _ShapeSegmentSlice? _sliceShapeSegment({
    required List<LatLng> shapePoints,
    required LatLng fermataA,
    required LatLng fermataB,
  }) {
    if (shapePoints.isEmpty) return null;

    final idxA = _nearestShapeIndex(shapePoints, fermataA);
    if (idxA < 0) return null;

    final idxB = _nearestShapeIndex(
      shapePoints,
      fermataB,
      startInclusive: idxA + 1,
    );
    if (idxB <= idxA) return null;

    final risultato = List<LatLng>.from(shapePoints.sublist(idxA, idxB + 1));
    if (risultato.length < 2) return null;

    final boardGap = _distanceMeters(fermataA, shapePoints[idxA]);
    final alightGap = _distanceMeters(fermataB, shapePoints[idxB]);
    _anchorSliceEndpoint(
      risultato,
      endpointIndex: 0,
      target: fermataA,
      gapMeters: boardGap,
    );
    _anchorSliceEndpoint(
      risultato,
      endpointIndex: risultato.length - 1,
      target: fermataB,
      gapMeters: alightGap,
    );

    return _ShapeSegmentSlice(
      points: risultato,
      indexSalita: idxA,
      indexDiscesa: idxB,
      boardGapMeters: boardGap,
      alightGapMeters: alightGap,
    );
  }

  static void _anchorSliceEndpoint(
    List<LatLng> slice, {
    required int endpointIndex,
    required LatLng target,
    required double gapMeters,
  }) {
    if (gapMeters <= _maxStopAnchorGapMeters) {
      slice[endpointIndex] = target;
    }
  }

  static bool _endpointChordTooLong(List<LatLng> segment) {
    if (segment.length < 2) return true;
    final first = _distanceMeters(segment[0], segment[1]);
    final last = _distanceMeters(
      segment[segment.length - 2],
      segment[segment.length - 1],
    );
    return first > _maxEndpointChordMeters || last > _maxEndpointChordMeters;
  }

  /// Salita e discesa devono comparire sullo shape nello stesso ordine del viaggio.
  static Future<bool> _shapeSupportsTripStopOrder({
    required List<LatLng> shapePoints,
    required String tripId,
    required String boardStopId,
    required String alightStopId,
    required Map<String, LatLng> stopMap,
  }) async {
    final trip = (await PercorsoPlannerIndex.load()).trips[tripId];
    if (trip == null) return true;

    final boardOnTrip = trip.stopById(boardStopId);
    final alightOnTrip = trip.stopById(alightStopId);
    if (boardOnTrip == null || alightOnTrip == null) return true;
    if (alightOnTrip.sequence <= boardOnTrip.sequence) return false;

    final boardPt = stopMap[boardStopId];
    final alightPt = stopMap[alightStopId];
    if (boardPt == null || alightPt == null) return true;

    final idxA = _nearestShapeIndex(shapePoints, boardPt);
    if (idxA < 0) return false;
    final idxB = _nearestShapeIndex(
      shapePoints,
      alightPt,
      startInclusive: idxA + 1,
    );
    if (idxB <= idxA) return false;

    final gapA = _distanceMeters(boardPt, shapePoints[idxA]);
    final gapB = _distanceMeters(alightPt, shapePoints[idxB]);
    return gapA <= 480 && gapB <= 480;
  }

  /// Indice del punto shape più vicino a [target] (Haversine), opzionalmente da [startInclusive].
  static int _nearestShapeIndex(
    List<LatLng> shapePoints,
    LatLng target, {
    int startInclusive = 0,
  }) {
    if (startInclusive >= shapePoints.length) return -1;
    var bestIndex = -1;
    var bestMeters = double.infinity;
    for (var i = startInclusive; i < shapePoints.length; i++) {
      final meters = _distanceMeters(shapePoints[i], target);
      if (meters < bestMeters) {
        bestMeters = meters;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  static Future<List<String>> _assetsForLeg({
    required String basin,
    required String routeId,
    String? tripId,
    String? boardStopId,
    String? alightStopId,
  }) async {
    final resolvedRouteId = _shapeRouteAlias(basin, routeId);
    final extraRoutes = _supplementaryShapeRouteIds(
      basin: basin,
      routeId: routeId,
      boardStopId: boardStopId,
      alightStopId: alightStopId,
    );
    final routeIds = <String>[
      ...extraRoutes,
      resolvedRouteId,
    ];
    final assets = <String>[];
    final seen = <String>{};
    for (final rid in routeIds) {
      for (final a in await listGpxAssetsForRoute(basin, rid)) {
        if (seen.add(a)) assets.add(a);
      }
    }
    if (assets.isEmpty || tripId == null || boardStopId == null) {
      return _orderAssets(
        assets,
        basin: basin,
        routeId: routeId,
        tripId: tripId,
        boardStopId: boardStopId,
        alightStopId: alightStopId,
      );
    }

    final trip = (await PercorsoPlannerIndex.load()).trips[tripId];
    final board = trip?.stopById(boardStopId);
    if (board == null) return assets;

    final depKey = _normTimeKey(board.depRaw);
    final matched = <String>[];
    final rest = <String>[];
    for (final asset in assets) {
      final sig = _timesFromGpxBasename(asset).map(_normTimeKey).toSet();
      if (sig.contains(depKey)) {
        matched.add(asset);
      } else {
        rest.add(asset);
      }
    }
    final ordered = matched.isEmpty ? assets : [...matched, ...rest];
    return _orderAssets(
      ordered,
      basin: basin,
      routeId: routeId,
      tripId: tripId,
      boardStopId: boardStopId,
      alightStopId: alightStopId,
    );
  }

  static List<String> _orderAssets(
    List<String> assets, {
    required String basin,
    required String routeId,
    String? tripId,
    String? boardStopId,
    String? alightStopId,
  }) {
    final preferredHints = _preferredAssetHints(
      basin: basin,
      routeId: routeId,
      tripId: tripId,
      boardStopId: boardStopId,
      alightStopId: alightStopId,
    );
    if (preferredHints.isEmpty) return assets;
    final preferred = <String>[];
    final others = <String>[];
    for (final a in assets) {
      final low = a.toLowerCase();
      if (preferredHints.any(low.contains)) {
        preferred.add(a);
      } else {
        others.add(a);
      }
    }
    return preferred.isEmpty ? assets : [...preferred, ...others];
  }

  /// Altre cartelle shape per lo stesso corridoio (es. F126 costa → anche 2CO).
  static List<String> _supplementaryShapeRouteIds({
    required String basin,
    required String routeId,
    String? boardStopId,
    String? alightStopId,
  }) {
    final b = basin.trim().toUpperCase();
    final r = routeId.trim().toUpperCase();
    if (b != 'FC') return const [];

    const coastal = {
      '11800', '11801', '11812', '11822', '11830',
      '11771', '11772', '10861', '10862', '10851', '10852',
      '10842', '10832', '10822', '10812', '10802',
      '30162', '30152', '30432', '30402',
      '30081', '30082', '30090', '30110', '30111',
      '10712', '10722', '15942',
    };
    final board = boardStopId?.trim() ?? '';
    final alight = alightStopId?.trim() ?? '';
    final coastalLeg = coastal.contains(board) || coastal.contains(alight);

    if (r == 'F126' && coastalLeg) return const ['1CO', '2CO'];
    return const [];
  }

  static String _shapeRouteAlias(String basin, String routeId) {
    // Ogni route_id estivo ha la propria cartella sotto assets/shapes/{bacino}/.
    return routeId;
  }

  static Future<Map<String, LatLng>> _loadStopsById() {
    final c = _stopsByIdCache;
    if (c != null) return Future.value(c);
    return _stopsByIdLoading ??= _loadStopsByIdInternal().then((value) {
      _stopsByIdCache = value;
      return value;
    });
  }

  static Future<Map<String, LatLng>> _loadStopsByIdInternal() async {
    final out = <String, LatLng>{};
    for (final path in kTransitLineStopAssetPaths) {
      try {
        final raw = await rootBundle.loadString(path);
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) continue;
        final stops = decoded['stops'];
        if (stops is! List) continue;
        for (final row in stops) {
          if (row is! Map<String, dynamic>) continue;
          final idRaw = row['id'];
          final latRaw = row['lat'];
          final lonRaw = row['long'];
          final id = idRaw?.toString().trim() ?? '';
          if (id.isEmpty || latRaw is! num || lonRaw is! num) continue;
          final p = LatLng(latRaw.toDouble(), lonRaw.toDouble());
          if (!_isFinite(p)) continue;
          out[id] = p;
        }
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  static LatLng _resolveStopPoint(
    Map<String, LatLng> stopsById,
    String? stopId,
    LatLng fallback,
  ) {
    final id = stopId?.trim() ?? '';
    if (id.isEmpty) return fallback;
    return stopsById[id] ?? fallback;
  }

  static Future<String?> _tripDepartureKey({
    String? tripId,
    String? boardStopId,
  }) async {
    if (tripId == null || boardStopId == null) return null;
    final trip = (await PercorsoPlannerIndex.load()).trips[tripId];
    final board = trip?.stopById(boardStopId);
    if (board == null) return null;
    return _normTimeKey(board.depRaw);
  }

  static Future<Map<String, Set<String>>> _loadDeparturesByShape({
    required String basin,
    required String routeId,
  }) async {
    final key = '${basin.toUpperCase()}|${routeId.toUpperCase()}';
    final cached = _shapeDeparturesCache[key];
    if (cached != null) return cached;

    final path = '${shapesFolderPrefix(basin, routeId)}partenze_per_shape.txt';
    final out = <String, Set<String>>{};
    try {
      final raw = await rootBundle.loadString(path);
      String? currentShapeId;
      final lines = raw.split(RegExp(r'\r?\n'));
      for (final line in lines) {
        final t = line.trim();
        if (t.isEmpty || t == '---' || t.startsWith('#')) continue;
        if (t.toLowerCase().startsWith('shape_id')) {
          final m = RegExp(
            r'^shape_id\s+(\d+)$',
            caseSensitive: false,
          ).firstMatch(t);
          currentShapeId = m?.group(1);
          continue;
        }
        if (currentShapeId == null) continue;
        if (RegExp(r'^\d{4}(\s+\d{4})+$').hasMatch(t) ||
            RegExp(r'^\d{4}$').hasMatch(t)) {
          final set = out.putIfAbsent(currentShapeId, () => <String>{});
          for (final hhmm in t.split(RegExp(r'\s+'))) {
            if (hhmm.length != 4) continue;
            set.add('${hhmm.substring(0, 2)}:${hhmm.substring(2, 4)}');
          }
        }
      }
    } catch (_) {
      // No departures file: keep map empty and continue with geometric scoring.
    }

    _shapeDeparturesCache[key] = out;
    return out;
  }

  static Future<_ShapeAssetRecord> _loadShapeAssetRecord(String asset) async {
    final cached = _shapeAssetCache[asset];
    if (cached != null) return cached;

    final points = await _loadGpx(asset);
    final shapeId = await _shapeIdFromAsset(asset);
    final rec = _ShapeAssetRecord(
      asset: asset,
      shapeId: shapeId,
      points: points,
    );
    _shapeAssetCache[asset] = rec;
    return rec;
  }

  static Future<String?> _shapeIdFromAsset(String asset) async {
    final byName = RegExp(
      r'__(\d+)\.gpx$',
      caseSensitive: false,
    ).firstMatch(asset)?.group(1);
    if (byName != null && byName.isNotEmpty) return byName;

    try {
      final head = await _loadAssetHeadUtf8(asset, 16384);
      return parseGpxTrackNameMeta(head).shapeId;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _loadAssetHeadUtf8(
    String assetPath,
    int maxBytes,
  ) async {
    final bd = await rootBundle.load(assetPath);
    final bytes = bd.buffer.asUint8List();
    final n = bytes.length < maxBytes ? bytes.length : maxBytes;
    return utf8.decode(bytes.sublist(0, n), allowMalformed: true);
  }

  static double _shapeScore({
    required String? shapeId,
    required Map<String, Set<String>> departuresByShape,
    required String? depKey,
    required double boardGapMeters,
    required double alightGapMeters,
    required double slicedLengthMeters,
    required double maxSegmentMeters,
    required double directMeters,
  }) {
    final timePenalty = _departureTimePenalty(
      depKey: depKey,
      shapeId: shapeId,
      departuresByShape: departuresByShape,
    );

    // Penalizza tratti con salti lunghi (shape sbagliato o corda fuorviante).
    final jumpLimit = directMeters < 500 ? 400.0 : directMeters * 0.14;
    final jumpPenalty =
        maxSegmentMeters > jumpLimit ? (maxSegmentMeters - jumpLimit) * 40.0 : 0.0;

    return timePenalty +
        jumpPenalty +
        (boardGapMeters * 10.0) +
        (alightGapMeters * 14.0) +
        (slicedLengthMeters * 0.15) +
        _sliceLengthRatioPenalty(
          directMeters: directMeters,
          slicedLengthMeters: slicedLengthMeters,
        );
  }

  /// Su trattti corti preferisce GPX il cui sotto-tracciato non è molto più lungo della corda.
  static double _sliceLengthRatioPenalty({
    required double directMeters,
    required double slicedLengthMeters,
  }) {
    if (directMeters <= 0 || slicedLengthMeters <= 0) return 0;
    if (directMeters >= 900) return 0;
    final ratio = slicedLengthMeters / directMeters;
    if (ratio <= 2.2) return 0;
    return (ratio - 2.2) * directMeters * 2.5;
  }

  /// Penalità orario: match esatto = 0; vicino (≤45 min) = penalità moderata.
  static double _departureTimePenalty({
    required String? depKey,
    required String? shapeId,
    required Map<String, Set<String>> departuresByShape,
  }) {
    if (depKey == null) return 0;
    final times = shapeId == null ? null : departuresByShape[shapeId];
    if (times == null || times.isEmpty) return 2500;
    if (times.contains(depKey)) return 0;

    final depMin = _minutesOfDay(depKey);
    if (depMin == null) return 50000;

    var bestDelta = 24 * 60;
    for (final raw in times) {
      final tMin = _minutesOfDay(raw);
      if (tMin == null) continue;
      var delta = (depMin - tMin).abs();
      if (delta > 12 * 60) delta = 24 * 60 - delta;
      if (delta < bestDelta) bestDelta = delta;
    }

    if (bestDelta <= 20) return bestDelta * 80.0;
    if (bestDelta <= 45) return 2000 + bestDelta * 120.0;
    return 100000.0;
  }

  static int? _minutesOfDay(String hhmm) {
    final p = hhmm.trim().split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null || h > 23 || m > 59) return null;
    return h * 60 + m;
  }

  static double _maxSegmentMeters(List<LatLng> points) {
    if (points.length < 2) return 0;
    var maxSeg = 0.0;
    for (var i = 1; i < points.length; i++) {
      final seg = _distanceMeters(points[i - 1], points[i]);
      if (seg > maxSeg) maxSeg = seg;
    }
    return maxSeg;
  }

  static bool _isLengthCompatible(double directMeters, double slicedMeters) {
    if (slicedMeters <= 0) return false;
    if (directMeters <= 50) return slicedMeters <= 500;
    final minFactor = directMeters < 500 ? 0.35 : 0.55;
    if (slicedMeters < directMeters * minFactor) return false;
    // Linee urbane (es. CE03 Cesena): il bus può superare 2× la corda pur restando plausibile.
    if (directMeters < 900) return slicedMeters <= directMeters * 5.0;
    if (directMeters < 1500) return slicedMeters <= directMeters * 4.5;
    if (directMeters < 3000) return slicedMeters <= directMeters * 4.5;
    return slicedMeters <= directMeters * 4.2;
  }

  /// Tratto molto corto ma con salita/discesa vicine al GPX (es. porto-canale 2CO).
  static bool _isMicroShapeSlice({
    required double directMeters,
    required double slicedLengthMeters,
    required double boardGapMeters,
    required double alightGapMeters,
  }) {
    if (directMeters <= 0 || directMeters >= 700) return false;
    if (slicedLengthMeters < 8 || slicedLengthMeters > directMeters * 0.35) {
      return false;
    }
    return boardGapMeters <= 80 && alightGapMeters <= 80;
  }

  static Future<List<LatLng>> _loadGpx(String asset) async {
    final cached = _fullLineCache[asset];
    if (cached != null) return cached;
    try {
      final raw = await rootBundle.loadString(asset);
      final pts = _finiteOnly(latLngsFromGpxString(raw));
      if (pts.length >= 2) _fullLineCache[asset] = pts;
      return pts;
    } catch (_) {
      return const [];
    }
  }

  static double _distanceMeters(LatLng a, LatLng b) {
    const dist = Distance();
    return dist.as(LengthUnit.Meter, a, b);
  }

  static double _polylineLengthMeters(List<LatLng> points) {
    if (points.length < 2) return 0;
    const dist = Distance();
    var sum = 0.0;
    for (var i = 1; i < points.length; i++) {
      sum += dist.as(LengthUnit.Meter, points[i - 1], points[i]);
    }
    return sum;
  }

  static List<String> _preferredAssetHints({
    required String basin,
    required String routeId,
    String? tripId,
    String? boardStopId,
    String? alightStopId,
  }) {
    final b = basin.trim().toUpperCase();
    final r = routeId.trim().toUpperCase();
    final trip = (tripId ?? '').trim();
    final board = (boardStopId ?? '').trim();
    final alight = (alightStopId ?? '').trim();

    if (b == 'FC' && r == 'S094' && trip == '818_1038680') {
      return const ['cesenatico_p_to_canale_to_cesena_punto_bus_a2'];
    }
    if (b == 'FC' && r == 'S094' && trip == '818_1038688') {
      return const ['cesenatico_p_to_canale_to_cesena_punto_bus_a2'];
    }
    if (b == 'FC' && r == 'S095' && trip == '818_1032760') {
      return const ['cesena_punto_bus_b1_to_fs'];
    }
    if (b == 'FC' && r == 'S094' && board == '15942' && alight == '999A2') {
      return const ['cesenatico_p_to_canale_to_cesena_punto_bus_a2'];
    }
    if (b == 'FC' &&
        r == 'S095' &&
        (board == '10431' || board == '10432') &&
        alight == '20102') {
      return const ['cesena_punto_bus_b1_to_fs'];
    }
    if (b == 'FC' && r == 'F126' && (board == '11800' || board == '11801')) {
      if (alight == '11771' ||
          alight == '11772' ||
          alight == '10861' ||
          alight == '10862' ||
          alight == '30090') {
        return const [
          'gatteo_mare_via_euclide_to_cesenatico',
          'cesenatico_ospedale_to_zadina',
          'stazione_cesenatico_to_zadina',
        ];
      }
      return const ['gatteo_mare_via_euclide_to_cesenatico'];
    }
    if (b == 'FC' &&
        r == 'F126' &&
        (alight == '11771' || alight == '11772' || alight == '30090')) {
      return const [
        'cesenatico_ospedale_to_zadina',
        'stazione_cesenatico_to_zadina',
      ];
    }
    if (b == 'FC' && r == '2CO' && (board == '11800' || board == '11801')) {
      return const [
        'gatteo_mare_via_euclide_to_cesenatico',
        'cesenatico_ospedale_to_zadina',
      ];
    }
    return const [];
  }

  /// Il sotto-tracciato deve seguire il verso di marcia board → alight.
  static bool _segmentFollowsTravelDirection(
    List<LatLng> segment,
    LatLng board,
    LatLng alight,
  ) {
    if (segment.length < 2) return false;
    final tLat = alight.latitude - board.latitude;
    final tLon = alight.longitude - board.longitude;
    final sLat = segment.last.latitude - segment.first.latitude;
    final sLon = segment.last.longitude - segment.first.longitude;
    const eps = 1e-6;
    if (tLat.abs() < eps && tLon.abs() < eps) return true;
    return (tLat * sLat + tLon * sLon) > 0;
  }

  static List<String> _timesFromGpxBasename(String assetPath) {
    final base = assetPath.split('/').last;
    final m = RegExp(
      r'_(\d{4}(?:-\d{4})*)__(?:\d+)\.gpx$',
      caseSensitive: false,
    ).firstMatch(base);
    if (m == null) return const [];
    final out = <String>[];
    for (final four in m.group(1)!.split('-')) {
      if (four.length != 4 || !RegExp(r'^\d{4}$').hasMatch(four)) continue;
      final h = int.tryParse(four.substring(0, 2));
      final mi = int.tryParse(four.substring(2, 4));
      if (h == null || mi == null || h > 23 || mi > 59) continue;
      out.add(
        '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}',
      );
    }
    return out;
  }

  static String _normTimeKey(String raw) {
    final p = raw.trim().split(':');
    if (p.length >= 2) {
      final h = int.tryParse(p[0]) ?? 0;
      final m = int.tryParse(p[1]) ?? 0;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    return raw.trim();
  }

  static bool _isFinite(LatLng p) =>
      p.latitude.isFinite && p.longitude.isFinite;

  static List<LatLng> _finiteOnly(List<LatLng> pts) =>
      pts.where(_isFinite).toList(growable: false);
}

class _ShapeAssetRecord {
  const _ShapeAssetRecord({
    required this.asset,
    required this.shapeId,
    required this.points,
  });

  final String asset;
  final String? shapeId;
  final List<LatLng> points;
}

class _ShapeSlicePick {
  const _ShapeSlicePick({required this.points, required this.score});

  final List<LatLng> points;
  final double score;
}

class _ShapeSegmentSlice {
  const _ShapeSegmentSlice({
    required this.points,
    required this.indexSalita,
    required this.indexDiscesa,
    required this.boardGapMeters,
    required this.alightGapMeters,
  });

  final List<LatLng> points;
  final int indexSalita;
  final int indexDiscesa;
  final double boardGapMeters;
  final double alightGapMeters;
}
