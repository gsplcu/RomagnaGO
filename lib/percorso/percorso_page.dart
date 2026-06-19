import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../linee_percorsi.dart';
import '../photon_romagna.dart';
import '../romagna_brand.dart';
import '../romagna_search_hit_ui.dart';
import '../transit_stops.dart';
import '../navette_bussi_page.dart';
import '../navette_cesenatico_page.dart';
import '../navette_milano_marittima_page.dart';
import '../navette_navettomare_page.dart';
import 'percorso_detail_page.dart';
import 'percorso_line_colors.dart';
import 'percorso_models.dart';
import 'percorso_navetta_hints.dart';
import 'percorso_stops.dart';
import 'percorso_search.dart';
import 'percorso_walk.dart';
import 'graphhopper_walk.dart';
import 'percorso_walk_enrich.dart';

class PercorsoPage extends StatefulWidget {
  const PercorsoPage({super.key, this.priorityOrigin});

  final LatLng? priorityOrigin;

  @override
  State<PercorsoPage> createState() => _PercorsoPageState();
}

class _PercorsoPageState extends State<PercorsoPage> {
  static const String _kRecentSearchesPrefsKey = 'percorso_recent_searches_v1';
  static const int _kMaxRecentSearches = 5;

  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _fromFocus = FocusNode();
  final _toFocus = FocusNode();

  List<TransitStopPin> _stops = const [];
  PercorsoSearchService? _search;
  bool _loadingData = true;
  String? _loadError;

  PercorsoEndpoint? _from;
  PercorsoEndpoint? _to;
  DateTime _departAt = DateTime.now();

  List<RomagnaAddressHit> _suggestions = const [];
  bool _searching = false;
  _ActiveField? _active;
  Timer? _debounce;

  List<PercorsoItinerary> _results = const [];
  List<PercorsoNavettaHint> _navettaHints = const [];
  bool _planning = false;
  String? _planHint;
  String? _planError;
  bool _searchBannerDismissed = false;
  List<_RecentPercorsoSearch> _recentSearches = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _loadRecentSearches();
    _fromCtrl.addListener(_onQueryChanged);
    _toCtrl.addListener(_onQueryChanged);
    _fromFocus.addListener(_onFocusChanged);
    _toFocus.addListener(_onFocusChanged);
  }

  Future<void> _bootstrap() async {
    // GraphHopper estrae asset pesanti: non blocca l'apertura della sezione.
    unawaited(GraphHopperWalkService.instance.initialize());

    try {
      final stopsFuture = loadTransitStopsFromAssets();
      final svcFuture = PercorsoSearchService.load();

      final stops = await stopsFuture;
      if (!mounted) return;
      setState(() {
        _stops = stops;
        _loadingData = false;
      });

      final svc = await svcFuture;
      if (!mounted) return;
      setState(() {
        _search = svc;
        _loadError = svc == null ? 'Dati percorso non disponibili' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingData = false;
        _loadError = 'Errore caricamento dati';
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_fromFocus.hasFocus) {
      _debounce?.cancel();
      setState(() {
        _searchBannerDismissed = true;
        _active = _ActiveField.from;
        _suggestions = const [];
      });
    } else if (_toFocus.hasFocus) {
      _debounce?.cancel();
      setState(() {
        _searchBannerDismissed = true;
        _active = _ActiveField.to;
        _suggestions = const [];
      });
      if (_toCtrl.text.trim().length >= 2) _runSearch(_toCtrl.text);
    }
  }

  void _onQueryChanged() {
    final q = _active == _ActiveField.to ? _toCtrl.text : _fromCtrl.text;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: kRomagnaSearchDebounceMs),
      () {
        if (mounted) _runSearch(q);
      },
    );
  }

  Future<void> _runSearch(String raw) async {
    final q = raw.trim();
    if (q.length < 2) {
      if (mounted) setState(() => _suggestions = const []);
      return;
    }
    setState(() => _searching = true);
    try {
      final hits = await searchRomagnaPercorso(
        q,
        transitStops: _stops,
        priorityOrigin: widget.priorityOrigin,
        maxMergedStops: 6,
        maxRemotePlaces: 20,
      );
      if (mounted) setState(() => _suggestions = hits);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  List<String> _stopClusterIdsForUi(String? stopId) {
    final id = stopId?.trim() ?? '';
    if (id.isEmpty) return const [];
    final svc = _search;
    if (svc != null) {
      return svc.resolveStopClusterIds(id).toList()..sort();
    }
    return [id];
  }

  void _selectHit(RomagnaAddressHit hit) {
    if (hit.isSearchMessage) return;
    final cluster = _stopClusterIdsForUi(hit.transitStopCode);
    final ep = PercorsoEndpoint(
      label: hit.label,
      point: hit.point,
      stopId: hit.transitStopCode,
      stopName: hit.transitStopName,
      stopClusterIds: cluster,
    );
    if (_active == _ActiveField.to) {
      _to = ep;
      _toCtrl.text = hit.label;
      _toFocus.unfocus();
    } else {
      _from = ep;
      _fromCtrl.text = hit.label;
      _fromFocus.unfocus();
    }
    setState(() {
      _searchBannerDismissed = true;
      _suggestions = const [];
      _active = null;
    });
  }

  Future<void> _swapEndpoints() async {
    final f = _from;
    final t = _to;
    final fc = _fromCtrl.text;
    final tc = _toCtrl.text;
    setState(() {
      _from = t;
      _to = f;
      _fromCtrl.text = tc;
      _toCtrl.text = fc;
    });
  }

  Future<void> _useMyLocation() async {
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attiva il GPS per usare la posizione attuale.'),
            ),
          );
        }
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.unableToDetermine) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Posizione bloccata. Abilitala nelle impostazioni.',
              ),
            ),
          );
        }
        return;
      }
      if (perm != LocationPermission.whileInUse &&
          perm != LocationPermission.always) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _from = PercorsoEndpoint(label: 'Posizione attuale', point: point);
        _fromCtrl.text = 'Posizione attuale';
        _suggestions = const [];
        _active = null;
      });
      _fromFocus.unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile ottenere la posizione.')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _departAt,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('it', 'IT'),
    );
    if (date == null || !mounted) return;
    setState(() {
      _departAt = DateTime(
        date.year,
        date.month,
        date.day,
        _departAt.hour,
        _departAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _departAt = DateTime(
        _departAt.year,
        _departAt.month,
        _departAt.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kRecentSearchesPrefsKey) ?? const [];
      final parsed = raw
          .map(_RecentPercorsoSearch.tryParse)
          .whereType<_RecentPercorsoSearch>()
          .toList(growable: false);
      if (!mounted) return;
      setState(
        () =>
            _recentSearches = parsed
                .take(_kMaxRecentSearches)
                .toList(growable: false),
      );
    } catch (_) {}
  }

  Future<void> _saveRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _kRecentSearchesPrefsKey,
        _recentSearches.map((e) => e.encode()).toList(growable: false),
      );
    } catch (_) {}
  }

  Future<void> _storeRecentSearch() async {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;
    final next = _RecentPercorsoSearch(
      from: from,
      to: to,
      fromLabel: from.label,
      toLabel: to.label,
      departAt: _departAt,
    );
    final updated = <_RecentPercorsoSearch>[next];
    for (final item in _recentSearches) {
      final samePair =
          item.fromLabel.toLowerCase() == next.fromLabel.toLowerCase() &&
          item.toLabel.toLowerCase() == next.toLabel.toLowerCase();
      if (!samePair) updated.add(item);
      if (updated.length >= _kMaxRecentSearches) break;
    }
    setState(() => _recentSearches = updated);
    await _saveRecentSearches();
  }

  Future<PercorsoEndpoint?> _resolveEndpointFromLabel(String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.toLowerCase() == 'posizione attuale') {
      try {
        final serviceOn = await Geolocator.isLocationServiceEnabled();
        if (!serviceOn) return null;
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.unableToDetermine) {
          perm = await Geolocator.requestPermission();
        }
        if (perm != LocationPermission.whileInUse &&
            perm != LocationPermission.always) {
          return null;
        }
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );
        return PercorsoEndpoint(
          label: 'Posizione attuale',
          point: LatLng(pos.latitude, pos.longitude),
        );
      } catch (_) {
        return null;
      }
    }

    final stopHits = busStopHitsForPercorsoSearch(
      trimmed,
      _stops,
      priorityOrigin: widget.priorityOrigin,
      maxMergedStops: 1,
    );
    if (stopHits.isNotEmpty) {
      final h = stopHits.first;
      final cluster = _stopClusterIdsForUi(h.transitStopCode);
      return PercorsoEndpoint(
        label: h.label,
        point: h.point,
        stopId: h.transitStopCode,
        stopName: h.transitStopName,
        stopClusterIds: cluster,
      );
    }

    final places = await searchRomagnaAddresses(
      trimmed,
      priorityOrigin: widget.priorityOrigin,
    );
    if (places.isEmpty) return null;
    final h = places.first;
    return PercorsoEndpoint(label: h.label, point: h.point);
  }

  Future<void> _applyRecentSearch(_RecentPercorsoSearch item) async {
    if (_planning) return;
    FocusScope.of(context).unfocus();

    PercorsoEndpoint? from = item.from;
    PercorsoEndpoint? to = item.to;

    setState(() {
      _searchBannerDismissed = true;
      _planning = true;
      _planError = null;
      _planHint = null;
      _results = const [];
      _navettaHints = const [];
      _active = null;
      _suggestions = const [];
    });

    from ??= await _resolveEndpointFromLabel(item.fromLabel);
    to ??= await _resolveEndpointFromLabel(item.toLabel);

    if (!mounted) return;
    if (from == null ||
        to == null ||
        !isValidPlannerLatLng(from.point) ||
        !isValidPlannerLatLng(to.point)) {
      setState(() {
        _planning = false;
        _planError =
            'Impossibile ripristinare il percorso. Riseleziona partenza e destinazione.';
      });
      return;
    }

    setState(() {
      _from = from;
      _to = to;
      _fromCtrl.text = from!.label;
      _toCtrl.text = to!.label;
    });

    await _plan();
  }

  Future<void> _plan() async {
    final svc = _search;
    final from = _from;
    final to = _to;
    if (svc == null) {
      setState(() => _planError = _loadError ?? 'Planner non pronto');
      return;
    }
    if (from == null || to == null) {
      setState(() => _planError = 'Seleziona partenza e destinazione');
      return;
    }
    if (!isValidPlannerLatLng(from.point) || !isValidPlannerLatLng(to.point)) {
      setState(
        () => _planError = 'Coordinate non valide: riseleziona gli indirizzi',
      );
      return;
    }
    await _storeRecentSearch();
    setState(() {
      _searchBannerDismissed = true;
      _planning = true;
      _planError = null;
      _planHint = null;
      _results = const [];
      _navettaHints = const [];
    });
    FocusScope.of(context).unfocus();
    try {
      final result = await svc
          .planDetailed(
            from: from,
            to: to,
            departAt: _departAt,
            profile: PercorsoProfile.fastest,
          )
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () {
              final walk = percorsoWalkEstimate(from.point, to.point);
              return PercorsoPlanResult(
                itineraries: [
                  PercorsoItinerary(
                    legs: [
                      PercorsoLeg(
                        kind: PercorsoLegKind.walk,
                        title: 'A piedi',
                        subtitle:
                            '${percorsoFormatWalkDistance(walk.meters)} \u00b7 '
                            '${from.label} \u2192 ${to.label}',
                        start: _departAt,
                        end: _departAt.add(
                          Duration(
                            seconds: (walk.duration.inSeconds).clamp(1, 86400),
                          ),
                        ),
                        from: from.point,
                        to: to.point,
                      ),
                    ],
                    totalDuration: walk.duration,
                    walkMeters: walk.meters,
                    transfers: 0,
                    profile: PercorsoProfile.fastest,
                    planQuality: PercorsoPlanQuality.walkOnlyFallback,
                  ),
                ],
                quality: PercorsoPlanQuality.walkOnlyFallback,
                suggestTrain: walk.meters >= 16000,
                userHint:
                    'Ricerca troppo lunga per questa tratta. '
                    'Valuta il treno se la distanza \u00e8 elevata (non ancora in app).',
              );
            },
          );
      if (!mounted) return;
      final enriched = await PercorsoWalkEnricher.enrichItineraries(
        result.itineraries,
      );
      final navettaHints = await PercorsoNavettaHints.detect(
        from: from,
        to: to,
        departAt: _departAt,
      ).catchError((Object e, StackTrace st) {
        debugPrint('PercorsoNavettaHints.detect: $e\n$st');
        return <PercorsoNavettaHint>[];
      });
      if (!mounted) return;
      setState(() {
        _results = enriched;
        _navettaHints = navettaHints;
        _planHint = result.userHint;
        _planning = false;
      });
    } catch (e, st) {
      debugPrint('PercorsoPage._plan: $e\n$st');
      if (!mounted) return;
      setState(() {
        _planning = false;
        _planError = 'Errore durante la ricerca';
      });
    }
  }

  void _resetSearchResults() {
    _fromCtrl.clear();
    _toCtrl.clear();
    _fromFocus.unfocus();
    _toFocus.unfocus();
    setState(() {
      _from = null;
      _to = null;
      _results = const [];
      _navettaHints = const [];
      _planHint = null;
      _planError = null;
      _active = null;
      _suggestions = const [];
      _searchBannerDismissed = false;
    });
  }

  void _openNavettaHintPage(BuildContext context, PercorsoNavettaHint hint) {
    final Widget page = switch (hint.kind) {
      PercorsoNavettaHintKind.cesenatico => const NavettaCesenaticoPage(),
      PercorsoNavettaHintKind.navettoMare65 ||
      PercorsoNavettaHintKind.navettoMare66 => const NavettoMarePage(),
      PercorsoNavettaHintKind.milanoMarittima =>
        const NavettaMilanoMarittimaPage(),
      PercorsoNavettaHintKind.busSi => const NavetteBusSiPage(),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _showFerryInfo() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _FerryInfoSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingData) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.2));
    }

    final isFromActive = _active == _ActiveField.from;
    final showSuggestions =
        _active != null &&
        (_suggestions.isNotEmpty || _searching || isFromActive);

    final showFerry = _results.isNotEmpty && _shouldShowFerryBanner(_from, _to);
    final showSearchGuidanceBanner =
        _results.isEmpty &&
        !_searchBannerDismissed &&
        _fromCtrl.text.trim().isEmpty &&
        _toCtrl.text.trim().isEmpty;

    final showNewSearchButton = _results.isNotEmpty && !_planning;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Percorso',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: kRomagnaDarkGray,
              ),
            ),
          ),
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _loadError!,
                style: GoogleFonts.inter(
                  color: Colors.red.shade700,
                  fontSize: 13,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _EndpointCard(
              fromController: _fromCtrl,
              toController: _toCtrl,
              fromFocus: _fromFocus,
              toFocus: _toFocus,
              onSwap: _swapEndpoints,
              onClearFrom: () {
                _fromCtrl.clear();
                _from = null;
                setState(() {});
              },
              onClearTo: () {
                _toCtrl.clear();
                _to = null;
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                CustomScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 4)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _DepartChip(
                                icon: Icons.calendar_today_rounded,
                                label: _formatDate(_departAt),
                                onTap: _pickDate,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DepartChip(
                                icon: Icons.schedule_rounded,
                                label: _formatTime(_departAt),
                                onTap: _pickTime,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: FilledButton(
                          onPressed:
                              (_planning || _search == null) ? null : _plan,
                          style: FilledButton.styleFrom(
                            backgroundColor: kRomagnaPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child:
                              _planning
                                  ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : _search == null
                                  ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Preparazione planner…',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  )
                                  : Text(
                                    'Cerca percorso',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                    if (_planHint != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color:
                                  _planHint!.contains('treno')
                                      ? const Color(0xFFFFF3E0)
                                      : const Color(0xFFE8F4FD),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                _planHint!,
                                style: GoogleFonts.inter(
                                  color:
                                      _planHint!.contains('treno')
                                          ? const Color(0xFFE65100)
                                          : const Color(0xFF1565C0),
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_planError != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            _planError!,
                            style: GoogleFonts.inter(
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    if (_results.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child:
                              _planning
                                  ? Center(
                                    child: Text(
                                      'Calcolo in corso\u2026',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  )
                                  : _RecentSearchesSection(
                                    items: _recentSearches,
                                    formatDateTime: _formatDateTime,
                                    onItemTap: _applyRecentSearch,
                                    planning: _planning,
                                  ),
                        ),
                      )
                    else ...[
                      if (_navettaHints.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                          sliver: SliverList.separated(
                            itemCount: _navettaHints.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 8),
                            itemBuilder:
                                (ctx, i) => _NavettaHintBanner(
                                  hint: _navettaHints[i],
                                  onTap:
                                      () => _openNavettaHintPage(
                                        context,
                                        _navettaHints[i],
                                      ),
                                ),
                          ),
                        ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          _navettaHints.isNotEmpty ? 10 : 8,
                          16,
                          24,
                        ),
                        sliver: SliverList.separated(
                          itemCount: _results.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final it = _results[i];
                            return _ItineraryTile(
                              itinerary: it,
                              lineByRouteKey:
                                  _search?.lineByRouteKey ?? const {},
                              onTap:
                                  () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder:
                                          (_) => PercorsoDetailPage(
                                            itinerary: it,
                                            lineByRouteKey:
                                                _search?.lineByRouteKey ??
                                                const {},
                                            planUserHint: _planHint,
                                          ),
                                    ),
                                  ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                if (showSuggestions)
                  Positioned(
                    top: 0,
                    left: 16,
                    right: 16,
                    child: _SuggestionsList(
                      hits: _suggestions,
                      searching: _searching,
                      onSelect: _selectHit,
                      showMyLocation: isFromActive,
                      onMyLocation: _useMyLocation,
                    ),
                  ),
              ],
            ),
          ),
          if (showFerry)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _FerryBanner(onTap: _showFerryInfo),
            ),
          if (showSearchGuidanceBanner)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _SearchTipsBanner(),
            ),
          if (showNewSearchButton)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: OutlinedButton.icon(
                onPressed: _resetSearchResults,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(
                  'Nuova ricerca',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kRomagnaPrimary,
                  side: BorderSide(
                    color: kRomagnaPrimary.withValues(alpha: 0.45),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  static String _formatTime(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  static String _formatDateTime(DateTime d) {
    return '${_formatDate(d)} · ${_formatTime(d)}';
  }
}

enum _ActiveField { from, to }

class _RecentPercorsoSearch {
  const _RecentPercorsoSearch({
    this.from,
    this.to,
    required this.fromLabel,
    required this.toLabel,
    required this.departAt,
  });

  final PercorsoEndpoint? from;
  final PercorsoEndpoint? to;
  final String fromLabel;
  final String toLabel;
  final DateTime departAt;

  factory _RecentPercorsoSearch.legacy({
    required String fromLabel,
    required String toLabel,
    required DateTime departAt,
  }) => _RecentPercorsoSearch(
    from: null,
    to: null,
    fromLabel: fromLabel,
    toLabel: toLabel,
    departAt: departAt,
  );

  String encode() => jsonEncode(<String, dynamic>{
    'fromLabel': fromLabel,
    'toLabel': toLabel,
    'departAt': departAt.toIso8601String(),
    if (from != null) 'from': _endpointToJson(from!),
    if (to != null) 'to': _endpointToJson(to!),
  });

  static _RecentPercorsoSearch? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('{')) {
      try {
        final m = jsonDecode(trimmed);
        if (m is! Map<String, dynamic>) return null;
        final dt = DateTime.tryParse(m['departAt'] as String? ?? '');
        if (dt == null) return null;
        final from = _endpointFromJson(m['from']);
        final to = _endpointFromJson(m['to']);
        final fromLabel =
            (m['fromLabel'] as String?)?.trim() ?? from?.label ?? '';
        final toLabel = (m['toLabel'] as String?)?.trim() ?? to?.label ?? '';
        if (fromLabel.isEmpty || toLabel.isEmpty) return null;
        return _RecentPercorsoSearch(
          from: from,
          to: to,
          fromLabel: fromLabel,
          toLabel: toLabel,
          departAt: dt,
        );
      } catch (_) {
        return null;
      }
    }
    final parts = trimmed.split('\t');
    if (parts.length != 3) return null;
    final dt = DateTime.tryParse(parts[2]);
    if (dt == null) return null;
    return _RecentPercorsoSearch.legacy(
      fromLabel: parts[0],
      toLabel: parts[1],
      departAt: dt,
    );
  }
}

Map<String, dynamic> _endpointToJson(PercorsoEndpoint e) => <String, dynamic>{
  'label': e.label,
  'lat': e.point.latitude,
  'lon': e.point.longitude,
  if (e.stopId != null && e.stopId!.isNotEmpty) 'stopId': e.stopId,
  if (e.stopName != null && e.stopName!.isNotEmpty) 'stopName': e.stopName,
  if (e.stopClusterIds.isNotEmpty) 'stopClusterIds': e.stopClusterIds,
};

PercorsoEndpoint? _endpointFromJson(Object? raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final lat = (m['lat'] as num?)?.toDouble();
  final lon = (m['lon'] as num?)?.toDouble();
  final label = (m['label'] as String?)?.trim() ?? '';
  if (lat == null || lon == null || label.isEmpty) return null;
  final clusterRaw = m['stopClusterIds'];
  final cluster =
      clusterRaw is List
          ? clusterRaw.map((e) => e.toString()).toList(growable: false)
          : const <String>[];
  return PercorsoEndpoint(
    label: label,
    point: LatLng(lat, lon),
    stopId: m['stopId'] as String?,
    stopName: m['stopName'] as String?,
    stopClusterIds: cluster,
  );
}

class _RecentSearchesSection extends StatelessWidget {
  const _RecentSearchesSection({
    required this.items,
    required this.formatDateTime,
    required this.onItemTap,
    required this.planning,
  });

  final List<_RecentPercorsoSearch> items;
  final String Function(DateTime) formatDateTime;
  final Future<void> Function(_RecentPercorsoSearch item) onItemTap;
  final bool planning;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cronologia delle ricerche',
            style: GoogleFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: kRomagnaDarkGray,
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              'Nessuna ricerca recente disponibile.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            )
          else
            ...List.generate(items.length, (index) {
              final item = items[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == items.length - 1 ? 0 : 8,
                ),
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE7EBEF)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: planning ? null : () => onItemTap(item),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.fromLabel} \u2192 ${item.toLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kRomagnaDarkGray,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatDateTime(item.departAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _SearchTipsBanner extends StatefulWidget {
  const _SearchTipsBanner();

  static void _showWhyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder:
          (ctx) =>
              _AddressSearchTipsDialog(onClose: () => Navigator.of(ctx).pop()),
    );
  }

  @override
  State<_SearchTipsBanner> createState() => _SearchTipsBannerState();
}

class _SearchTipsBannerState extends State<_SearchTipsBanner> {
  TapGestureRecognizer? _whyLinkTap;

  @override
  void dispose() {
    _whyLinkTap?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bodyColor = Color(0xFFB71C1C);
    final bodyStyle = GoogleFonts.inter(
      fontSize: 12,
      height: 1.3,
      color: bodyColor,
    );
    final linkStyle = bodyStyle.copyWith(
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: bodyColor,
    );

    _whyLinkTap ??= TapGestureRecognizer();
    _whyLinkTap!.onTap = () => _SearchTipsBanner._showWhyDialog(context);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE53935)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggerimento per una ricerca pi\u00f9 precisa',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: bodyColor,
            ),
          ),
          const SizedBox(height: 3),
          Text.rich(
            TextSpan(
              style: bodyStyle,
              children: [
                const TextSpan(
                  text:
                      'Inserisci via e numero civico invece del solo nome '
                      'del luogo o dell\u2019attivit\u00e0. ',
                ),
                TextSpan(
                  text: 'Scopri perch\u00e9',
                  style: linkStyle,
                  recognizer: _whyLinkTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressSearchTipsDialog extends StatelessWidget {
  const _AddressSearchTipsDialog({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Material(
              color: Colors.white,
              elevation: 10,
              shadowColor: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 48, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Perch\u00e9 via e numero civico?',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: kRomagnaDarkGray,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'RomagnaGO si basa sui dati di OpenStreetMap (OSM), '
                          'la mappa collaborativa libera. Non tutti i luoghi sono '
                          'segnalati correttamente, oppure mancano del tutto e non sono '
                          'aggiornati. Molti negozi, bar e attivit\u00e0 che trovi su '
                          'Google Maps non sono ancora presenti su OSM: cercando '
                          'solo il nome, potresti ottenere risultati imprecisi o '
                          'non trovare nulla. Via e numero civico funzionano meglio '
                          'perch\u00e9 gli indirizzi stradali sono sempre inseriti '
                          'correttamente.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.45,
                            color: kRomagnaDarkGray.withValues(alpha: 0.88),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Conosci solo il nome? Prova comunque nome e citt\u00e0 '
                          '(ad esempio \u00abBar Centrale Rimini\u00bb). Se non compare nulla, '
                          'cerca una fermata del bus nelle vicinanze, oppure usa '
                          'una mappa esterna per trovare l’indirizzo corretto.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.45,
                            color: kRomagnaDarkGray.withValues(alpha: 0.88),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      tooltip: 'Chiudi',
                      onPressed: onClose,
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EndpointCard extends StatelessWidget {
  const _EndpointCard({
    required this.fromController,
    required this.toController,
    required this.fromFocus,
    required this.toFocus,
    required this.onSwap,
    required this.onClearFrom,
    required this.onClearTo,
  });

  final TextEditingController fromController;
  final TextEditingController toController;
  final FocusNode fromFocus;
  final FocusNode toFocus;
  final VoidCallback onSwap;
  final VoidCallback onClearFrom;
  final VoidCallback onClearTo;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE8ECEF)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4, right: 4),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.trip_origin, size: 14, color: kRomagnaPrimary),
                const SizedBox(height: 30),
                Icon(Icons.place_rounded, size: 16, color: Colors.red.shade400),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  _buildField(
                    controller: fromController,
                    focus: fromFocus,
                    hint: 'Partenza',
                    onClear: onClearFrom,
                  ),
                  const Divider(height: 1),
                  _buildField(
                    controller: toController,
                    focus: toFocus,
                    hint: 'Destinazione',
                    onClear: onClearTo,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                onPressed: onSwap,
                icon: Icon(
                  Icons.swap_vert_rounded,
                  color: kRomagnaPrimary,
                  size: 22,
                ),
                tooltip: 'Inverti',
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focus,
    required String hint,
    required VoidCallback onClear,
  }) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          focusNode: focus,
          decoration: InputDecoration(
            hintText: hint,
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            hintStyle: GoogleFonts.inter(color: Colors.grey.shade500),
            suffixIcon:
                value.text.isNotEmpty
                    ? GestureDetector(
                      onTap: onClear,
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                    )
                    : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 28,
            ),
          ),
          style: GoogleFonts.inter(fontSize: 15),
        );
      },
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  const _SuggestionsList({
    required this.hits,
    required this.searching,
    required this.onSelect,
    this.showMyLocation = false,
    this.onMyLocation,
  });

  final List<RomagnaAddressHit> hits;
  final bool searching;
  final void Function(RomagnaAddressHit) onSelect;
  final bool showMyLocation;
  final VoidCallback? onMyLocation;

  @override
  Widget build(BuildContext context) {
    final myLocOffset = showMyLocation ? 1 : 0;
    final searchOffset = searching ? 1 : 0;
    final total = myLocOffset + searchOffset + hits.length;
    if (total == 0) return const SizedBox.shrink();

    final maxH = MediaQuery.sizeOf(context).height * 0.32;
    return Material(
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH.clamp(120.0, 220.0)),
        child: ListView.builder(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          itemCount: total,
          itemBuilder: (context, index) {
            if (showMyLocation && index == 0) {
              return ListTile(
                dense: true,
                leading: Icon(
                  Icons.my_location_rounded,
                  color: kRomagnaPrimary,
                  size: 22,
                ),
                title: Text(
                  'Posizione attuale',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kRomagnaPrimary,
                  ),
                ),
                onTap: onMyLocation,
              );
            }
            final adjusted = index - myLocOffset;
            if (searching && adjusted == 0) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final hi = adjusted - searchOffset;
            final h = hits[hi];
            return ListTile(
              dense: true,
              leading: romagnaSearchHitLeading(h),
              title: Text(
                h.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 14),
              ),
              onTap: h.isSearchMessage ? null : () => onSelect(h),
            );
          },
        ),
      ),
    );
  }
}

class _ItineraryTile extends StatelessWidget {
  const _ItineraryTile({
    required this.itinerary,
    required this.lineByRouteKey,
    required this.onTap,
  });

  final PercorsoItinerary itinerary;
  final Map<String, RomagnaLineaRow> lineByRouteKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rideLegs =
        itinerary.legs.where((l) => l.kind == PercorsoLegKind.ride).toList();

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE8ECEF)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            itinerary.summaryLine,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: kRomagnaDarkGray,
                            ),
                          ),
                        ),
                        if (itinerary.routingLabel != null)
                          _RoutingTagChip(label: itinerary.routingLabel!),
                      ],
                    ),
                    if (rideLegs.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final leg in rideLegs)
                            _LineBubble(
                              label: _extractLineNumber(leg),
                              color: _lineBubbleColor(leg.routeKey),
                            ),
                        ],
                      ),
                    ],
                    if (itinerary.recommendedWalkOnly) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Meglio a piedi del bus',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (itinerary.suggestedDayOffset != 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        itinerary.suggestedDayOffset > 0
                            ? 'Servizio in un giorno diverso da quello scelto'
                            : 'Servizio nel giorno precedente a quello scelto',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.deepPurple.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (itinerary.planQuality ==
                        PercorsoPlanQuality.walkOnlyFallback) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Solo a piedi \u00b7 nessun TPL in calendario',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (itinerary.departsLaterThanRequested) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Partenza dopo l\u2019orario richiesto',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.blueGrey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (itinerary.hasPrenotazione) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Corsa su prenotazione',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  String _extractLineNumber(PercorsoLeg leg) {
    final label = leg.lineLabel ?? '';
    if (label.startsWith('Linea ')) return label.substring(6);
    return label.isNotEmpty ? label : '?';
  }

  Color _lineBubbleColor(String? routeKey) =>
      legLineColor(routeKey, lineByRouteKey);
}

class _RoutingTagChip extends StatelessWidget {
  const _RoutingTagChip({required this.label});

  final PercorsoRoutingLabel label;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (label) {
      PercorsoRoutingLabel.fastest => (kRomagnaPrimary, Colors.white),
      PercorsoRoutingLabel.lessWalking => (
        const Color(0xFFE8F5E9),
        const Color(0xFF2E7D32),
      ),
      PercorsoRoutingLabel.fewerTransfers => (
        const Color(0xFFE3F2FD),
        const Color(0xFF1565C0),
      ),
      PercorsoRoutingLabel.smootherTravel => (
        const Color(0xFFF3E5F5),
        const Color(0xFF6A1B9A),
      ),
    };
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.tag,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _LineBubble extends StatelessWidget {
  const _LineBubble({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = color.computeLuminance() < 0.45;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? color : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : color,
        ),
      ),
    );
  }
}

class _DepartChip extends StatelessWidget {
  const _DepartChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE8ECEF)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: kRomagnaPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: kRomagnaDarkGray,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Navette consigliate (prima degli itinerari TPL)
// ---------------------------------------------------------------------------

class _NavettaHintBanner extends StatelessWidget {
  const _NavettaHintBanner({required this.hint, required this.onTap});

  final PercorsoNavettaHint hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: hint.accent.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: hint.accent.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: hint.accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Consiglio: prendi la navetta',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.2,
                        color: hint.accentDark,
                      ),
                    ),
                    Text(
                      hint.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        height: 1.25,
                        color: hint.accentDark.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: hint.accent.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ferry banner (task 5)
// ---------------------------------------------------------------------------

const LatLng _kMarinaDiRavenna = LatLng(44.491722, 12.279611);
const LatLng _kPortoCorsini = LatLng(44.493194, 12.281333);
const double _kFerryProximityMeters = 1500;

bool _isNearFerryTerminal(LatLng? point, LatLng terminal) {
  if (point == null) return false;
  const d = Distance();
  return d.as(LengthUnit.Meter, point, terminal) < _kFerryProximityMeters;
}

bool _shouldShowFerryBanner(PercorsoEndpoint? from, PercorsoEndpoint? to) {
  if (from == null || to == null) return false;
  final fromMarina = _isNearFerryTerminal(from.point, _kMarinaDiRavenna);
  final fromPorto = _isNearFerryTerminal(from.point, _kPortoCorsini);
  final toMarina = _isNearFerryTerminal(to.point, _kMarinaDiRavenna);
  final toPorto = _isNearFerryTerminal(to.point, _kPortoCorsini);
  return (fromMarina && toPorto) || (fromPorto && toMarina);
}

class _FerryBanner extends StatelessWidget {
  const _FerryBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE3F2FD),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF1A73FF), width: 0.8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(
                Icons.directions_boat_rounded,
                color: Color(0xFF1A73FF),
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Traghetto disponibile',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: const Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Marina di Ravenna \u2194 Porto Corsini',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF1565C0),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }
}

class _FerryInfoSheet extends StatelessWidget {
  const _FerryInfoSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              const Icon(
                Icons.directions_boat_rounded,
                color: Color(0xFF1A73FF),
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                'Traghetto Ravenna',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: kRomagnaDarkGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow(
            Icons.route_rounded,
            'Marina di Ravenna \u2194 Porto Corsini',
          ),
          const SizedBox(height: 8),
          _infoRow(
            Icons.schedule_rounded,
            'Servizio continuo, frequenza ogni 10\u201315 min',
          ),
          const SizedBox(height: 8),
          _infoRow(Icons.euro_rounded, 'Gratuito per pedoni e ciclisti'),
          const SizedBox(height: 8),
          _infoRow(
            Icons.access_time_rounded,
            'Attivo tutto l\u2019anno, orario ridotto notturno',
          ),
          const SizedBox(height: 8),
          _infoRow(Icons.directions_walk_rounded, 'Traversata: circa 3 minuti'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1A73FF),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Chiudi',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1565C0)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: kRomagnaDarkGray,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
