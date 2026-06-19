import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../linee_percorsi.dart';
import '../romagna_brand.dart';
import 'percorso_line_colors.dart';
import 'percorso_maps_launch.dart';
import 'percorso_models.dart';
import 'percorso_shapes.dart';
import 'percorso_walk_enrich.dart';

class PercorsoDetailPage extends StatefulWidget {
  const PercorsoDetailPage({
    super.key,
    required this.itinerary,
    this.lineByRouteKey = const {},
    this.planUserHint,
  });

  final PercorsoItinerary itinerary;
  final Map<String, RomagnaLineaRow> lineByRouteKey;
  final String? planUserHint;

  @override
  State<PercorsoDetailPage> createState() => _PercorsoDetailPageState();
}

class _PercorsoDetailPageState extends State<PercorsoDetailPage> {
  final _mapController = MapController();
  List<Polyline> _polylines = const [];
  List<LatLng> _fitPoints = const [];
  bool _mapLoading = true;
  bool _mapExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadMapGeometry();
  }

  Future<void> _loadMapGeometry() async {
    final lines = <Polyline>[];
    final fit = <LatLng>[];

    // Quando il routing pedonale reale è caduto (linea d'aria densificata),
    // i tratti a piedi vanno evidenziati come stima anomala.
    final brokenWalk = widget.itinerary.hasBrokenWalkConnection;
    final walkColor = brokenWalk
        ? const Color(0xFFE8821A).withValues(alpha: 0.85)
        : kRomagnaDarkGray.withValues(alpha: 0.65);
    final walkPattern = brokenWalk
        ? StrokePattern.dotted(spacingFactor: 1.6)
        : StrokePattern.dashed(segments: const [10, 6]);

    for (final leg in widget.itinerary.legs) {
      if (leg.kind == PercorsoLegKind.wait) continue;
      if (leg.from == null || leg.to == null) continue;

      final rideColor = legLineColor(leg.routeKey, widget.lineByRouteKey);

      if (leg.kind == PercorsoLegKind.ride &&
          leg.routeKey != null &&
          leg.routeKey!.isNotEmpty) {
        final pts = await PercorsoShapeCache.pointsForRideLeg(
          routeKey: leg.routeKey!,
          from: leg.from!,
          to: leg.to!,
          tripId: leg.tripId,
          boardStopId: leg.boardStopId,
          alightStopId: leg.alightStopId,
        );
        final safePts = _finiteLatLngs(pts);
        if (_isMeaningfulRidePolyline(safePts, leg.from!, leg.to!)) {
          lines.add(
            Polyline(
              points: safePts,
              strokeWidth: 4.5,
              color: rideColor,
            ),
          );
          fit.addAll(safePts);
          continue;
        }
      }

      List<LatLng> walkPts = leg.walkPath ?? const [];
      if (leg.kind == PercorsoLegKind.walk &&
          walkPts.length < 2 &&
          leg.from != null &&
          leg.to != null) {
        final enriched = await PercorsoWalkEnricher.enrichWalkLeg(leg);
        walkPts = enriched.walkPath ?? const [];
      }

      if (leg.kind == PercorsoLegKind.walk && walkPts.length >= 2) {
        final safeWalk = _normalizeWalkPath(walkPts, leg.from!, leg.to!);
        if (safeWalk.length >= 2) {
          lines.add(
            Polyline(
              points: safeWalk,
              strokeWidth: brokenWalk ? 3.5 : 3,
              color: walkColor,
              pattern: walkPattern,
            ),
          );
          fit.addAll(safeWalk);
          continue;
        }
      }

      if (leg.kind == PercorsoLegKind.ride) {
        // Evita linee dritte fuorvianti quando lo slice GPX non è affidabile.
        continue;
      }
      final fallback = _finiteLatLngs([leg.from!, leg.to!]);
      if (fallback.length < 2) continue;

      lines.add(
        Polyline(
          points: fallback,
          strokeWidth: leg.kind == PercorsoLegKind.walk
              ? (brokenWalk ? 3.5 : 3)
              : 4,
          color: leg.kind == PercorsoLegKind.walk ? walkColor : rideColor,
          pattern: leg.kind == PercorsoLegKind.walk
              ? walkPattern
              : const StrokePattern.solid(),
        ),
      );
      fit.addAll(fallback);
    }

    if (!mounted) return;
    setState(() {
      _polylines = lines;
      _fitPoints = fit;
      _mapLoading = false;
    });
    _fitMapWhenReady();
  }

  void _fitMapWhenReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final coords = _finiteLatLngs(_fitPoints);
      if (!mounted || coords.length < 2) return;
      try {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: coords,
            padding: const EdgeInsets.all(36),
          ),
        );
      } catch (_) {}
    });
  }

  void _toggleMapExpanded() {
    setState(() => _mapExpanded = !_mapExpanded);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapWhenReady());
  }

  Future<void> _openTurnByTurnNavigation() async {
    final (from, to) = percorsoWalkEndpoints(widget.itinerary);
    if (from == null || to == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coordinate percorso non disponibili')),
      );
      return;
    }
    final ok = await launchWalkingTurnByTurn(from: from, to: to);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile aprire la navigazione sul dispositivo'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.itinerary;
    final fallback = _fallbackBounds(it);
    final displayLegs = collapsePercorsoWaitLegs(it.legs);
    final showDirections = percorsoShowsTurnByTurnNavigation(
      itinerary: it,
      planUserHint: widget.planUserHint,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dettaglio percorso',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            height: _mapExpanded
                ? MediaQuery.of(context).size.height -
                    kToolbarHeight -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom -
                    56
                : 240,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: fallback.center,
                    initialZoom: fallback.zoom,
                    minZoom: 8,
                    maxZoom: 18,
                    onMapReady: _fitMapWhenReady,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'RomagnaGO',
                      maxNativeZoom: 19,
                    ),
                    if (_polylines.isNotEmpty)
                      PolylineLayer(polylines: _polylines),
                    MarkerLayer(markers: _markersFor(it)),
                  ],
                ),
                if (_mapLoading)
                  const ColoredBox(
                    color: Color(0x11000000),
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    ),
                  ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Material(
                    elevation: 2,
                    shape: const CircleBorder(),
                    color: Colors.white,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _toggleMapExpanded,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          _mapExpanded
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          size: 22,
                          color: kRomagnaDarkGray,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!_mapExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      it.summaryLine,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: kRomagnaDarkGray,
                      ),
                    ),
                  ),
                  if (it.routingLabel != null)
                    _RoutingLabelChip(label: it.routingLabel!),
                ],
              ),
            ),
            if (it.routingLabel != null &&
                it.routingLabel != PercorsoRoutingLabel.fastest)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    it.routingLabel!.banner,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: kRomagnaPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (it.hasBrokenWalkConnection)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: Colors.orange.shade800),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tempi del tratto a piedi stimati in linea d\u2019aria: '
                        'routing pedonale momentaneamente non disponibile.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.3,
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (it.recommendedWalkOnly)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'In queste condizioni il tragitto a piedi è più rapido del TPL.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: displayLegs.length,
                itemBuilder: (ctx, i) => _LegTile(
                  leg: displayLegs[i],
                  lineByRouteKey: widget.lineByRouteKey,
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar:
          showDirections
              ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    onPressed: _openTurnByTurnNavigation,
                    icon: const Icon(Icons.directions_walk_rounded),
                    label: Text(
                      'Indicazioni stradali',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: kRomagnaPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              )
              : null,
    );
  }

  List<Marker> _markersFor(PercorsoItinerary it) {
    final markers = <Marker>[];
    LatLng? first;
    LatLng? last;
    for (final leg in it.legs) {
      first ??= leg.from;
      if (leg.to != null) last = leg.to;
    }
    if (first != null && _isFiniteLatLng(first)) {
      markers.add(
        Marker(
          point: first,
          width: 28,
          height: 28,
          child: Icon(Icons.trip_origin, color: kRomagnaPrimary, size: 26),
        ),
      );
    }
    if (last != null && last != first && _isFiniteLatLng(last)) {
      markers.add(
        Marker(
          point: last,
          width: 28,
          height: 28,
          child: Icon(Icons.place_rounded, color: Colors.red.shade600, size: 28),
        ),
      );
    }
    return markers;
  }
}

class _MapBounds {
  const _MapBounds({required this.center, required this.zoom});

  final LatLng center;
  final double zoom;
}

_MapBounds _fallbackBounds(PercorsoItinerary it) {
  final pts = <LatLng>[];
  for (final leg in it.legs) {
    if (leg.from != null && _isFiniteLatLng(leg.from!)) pts.add(leg.from!);
    if (leg.to != null && _isFiniteLatLng(leg.to!)) pts.add(leg.to!);
  }
  if (pts.isEmpty) {
    return const _MapBounds(center: LatLng(44.22, 12.24), zoom: 11);
  }
  if (pts.length == 1) {
    return _MapBounds(center: pts.first, zoom: 14);
  }
  var minLat = pts.first.latitude;
  var maxLat = pts.first.latitude;
  var minLon = pts.first.longitude;
  var maxLon = pts.first.longitude;
  for (final p in pts) {
    minLat = minLat < p.latitude ? minLat : p.latitude;
    maxLat = maxLat > p.latitude ? maxLat : p.latitude;
    minLon = minLon < p.longitude ? minLon : p.longitude;
    maxLon = maxLon > p.longitude ? maxLon : p.longitude;
  }
  final c = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
  final span = (maxLat - minLat).abs() + (maxLon - minLon).abs();
  final zoom = span < 0.02 ? 14.0 : span < 0.08 ? 12.0 : 10.5;
  return _MapBounds(center: c, zoom: zoom);
}

bool _isFiniteLatLng(LatLng p) =>
    p.latitude.isFinite && p.longitude.isFinite;

List<LatLng> _finiteLatLngs(List<LatLng> pts) =>
    pts.where(_isFiniteLatLng).toList(growable: false);

List<LatLng> _normalizeWalkPath(List<LatLng> path, LatLng from, LatLng to) {
  final safe = _finiteLatLngs(path);
  if (safe.length < 2) return safe;
  final out = List<LatLng>.from(safe);
  out[0] = from;
  out[out.length - 1] = to;
  return out;
}

bool _isMeaningfulRidePolyline(List<LatLng> pts, LatLng from, LatLng to) {
  if (pts.length < 3) return false;
  const dist = Distance();
  var path = 0.0;
  for (var i = 1; i < pts.length; i++) {
    path += dist.as(LengthUnit.Meter, pts[i - 1], pts[i]);
  }
  final direct = dist.as(LengthUnit.Meter, from, to);
  return path > direct * 0.45;
}

class _RoutingLabelChip extends StatelessWidget {
  const _RoutingLabelChip({required this.label});

  final PercorsoRoutingLabel label;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (label) {
      PercorsoRoutingLabel.fastest => (kRomagnaPrimary, Colors.white),
      PercorsoRoutingLabel.lessWalking => (const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      PercorsoRoutingLabel.fewerTransfers => (const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
      PercorsoRoutingLabel.smootherTravel => (const Color(0xFFF3E5F5), const Color(0xFF6A1B9A)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.tag,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _LegTile extends StatelessWidget {
  const _LegTile({
    required this.leg,
    this.lineByRouteKey = const {},
  });

  final PercorsoLeg leg;
  final Map<String, RomagnaLineaRow> lineByRouteKey;

  @override
  Widget build(BuildContext context) {
    final rideColor = legLineColor(leg.routeKey, lineByRouteKey);
    final icon = switch (leg.kind) {
      PercorsoLegKind.walk => Icons.directions_walk_rounded,
      PercorsoLegKind.wait => Icons.hourglass_empty_rounded,
      PercorsoLegKind.ride => Icons.directions_bus_rounded,
    };
    final color = switch (leg.kind) {
      PercorsoLegKind.walk => kRomagnaDarkGray,
      PercorsoLegKind.wait => Colors.grey.shade600,
      PercorsoLegKind.ride => rideColor,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(icon, color: color, size: 24),
              if (leg.kind != PercorsoLegKind.wait)
                Container(
                  width: 2,
                  height: 36,
                  margin: const EdgeInsets.only(top: 4),
                  color: leg.kind == PercorsoLegKind.ride
                      ? rideColor.withValues(alpha: 0.3)
                      : const Color(0xFFE0E0E0),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        leg.title,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (leg.start != null && leg.end != null)
                      Text(
                        '${_hm(leg.start!)} – ${_hm(leg.end!)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else if (leg.start != null)
                      Text(
                        _hm(leg.start!),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                if (leg.subtitle.isNotEmpty)
                  Text(
                    leg.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.35,
                    ),
                  ),
                if (leg.isPrenotazione)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Su prenotazione',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _hm(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
