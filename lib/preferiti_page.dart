// Preferiti: fermate da fermate_fc|ra|rn.json, linee da linee.json (per bacino). Solo in memoria.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'linee_percorsi.dart';
import 'login_page.dart';
import 'romagna_brand.dart';
import 'transit_stops.dart';

class _FavoriteStopEntry {
  _FavoriteStopEntry({required this.bacinoUpper, required this.pin});

  final String bacinoUpper;
  final TransitStopPin pin;

  String get _idKey => pin.stopId.isEmpty ? '${pin.point.latitude}_${pin.point.longitude}' : pin.stopId;

  bool matches(_FavoriteStopEntry o) =>
      bacinoUpper == o.bacinoUpper && _idKey == o._idKey;
}

class _FavoriteLineEntry {
  _FavoriteLineEntry({required this.row});

  final RomagnaLineaRow row;

  bool matches(_FavoriteLineEntry o) => row.bacino == o.row.bacino && row.routeId == o.row.routeId;
}

/// Pagina Preferiti con bacino + fermata/linea da asset; elenco rimovibile sotto.
class PreferitiPage extends StatefulWidget {
  const PreferitiPage({super.key});

  @override
  State<PreferitiPage> createState() => _PreferitiPageState();
}

class _PreferitiPageState extends State<PreferitiPage> {
  static const _intro =
      'Scegli bacino e fermata o linea. Le preferenze restano in questa schermata (nessun salvataggio su disco per ora).';

  String _fermateBacino = kBaciniOrdine.first;
  String _lineeBacino = kBaciniOrdine.first;

  Map<String, List<RomagnaLineaRow>> _lineeByBacino = {};
  bool _lineeLoaded = false;

  final Map<String, List<TransitStopPin>> _stopsCache = {};
  final Map<String, Future<void>> _stopsInFlight = {};

  final List<_FavoriteStopEntry> _favoriteStops = [];
  final List<_FavoriteLineEntry> _favoriteLines = [];

  String? _lineDropdownValue;

  @override
  void initState() {
    super.initState();
    _loadLineeCatalog();
  }

  Future<void> _loadLineeCatalog() async {
    final all = await loadLineeCatalog();
    if (!mounted) return;
    setState(() {
      _lineeByBacino = groupLineeByBacino(all);
      _lineeLoaded = true;
    });
  }

  Future<List<TransitStopPin>> _stopsForBacino(String bacinoUpper) async {
    final cached = _stopsCache[bacinoUpper];
    if (cached != null) return cached;
    _stopsInFlight[bacinoUpper] ??= () async {
      final list = await loadTransitStopsForBasin(bacinoUpper);
      if (!mounted) return;
      setState(() => _stopsCache[bacinoUpper] = list);
    }();
    await _stopsInFlight[bacinoUpper];
    return _stopsCache[bacinoUpper] ?? const [];
  }

  void _addStop(_FavoriteStopEntry e) {
    if (_favoriteStops.any((x) => x.matches(e))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fermata già in elenco', style: GoogleFonts.inter())),
      );
      return;
    }
    setState(() => _favoriteStops.add(e));
  }

  void _addLine(RomagnaLineaRow row) {
    final e = _FavoriteLineEntry(row: row);
    if (_favoriteLines.any((x) => x.matches(e))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Linea già in elenco', style: GoogleFonts.inter())),
      );
      return;
    }
    setState(() => _favoriteLines.add(e));
  }

  Future<void> _openStopSearch() async {
    final bacino = _fermateBacino;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (ctx) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: _StopSearchSheet(
              bacinoLabel: bacino,
              loadPins: () => _stopsForBacino(bacino),
              onPick: (pin) {
                Navigator.pop(ctx);
                _addStop(_FavoriteStopEntry(bacinoUpper: bacino, pin: pin));
              },
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logged = FirebaseAuth.instance.currentUser != null;
    if (!logged) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          title: Text('Preferiti', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.white,
          foregroundColor: kRomagnaDarkGray,
          surfaceTintColor: Colors.transparent,
          elevation: 0.5,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 52,
                  color: kRomagnaDarkGray.withValues(alpha: 0.55),
                ),
                const SizedBox(height: 12),
                Text(
                  'Funzione disponibile solo con account',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kRomagnaDarkGray,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Accedi o registrati per usare i preferiti.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    height: 1.35,
                    color: kRomagnaDarkGray.withValues(alpha: 0.62),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed:
                      () => Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
                        (route) => false,
                      ),
                  child: Text(
                    'Vai al login',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final linee = _lineeByBacino[_lineeBacino] ?? const [];

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text('Preferiti', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          Text(
            _intro,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: kRomagnaDarkGray.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 20),
          _sectionCard(
            icon: Icons.location_on_outlined,
            title: 'Fermate preferite',
            children: [
              _bacinoDropdown(
                value: _fermateBacino,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _fermateBacino = v);
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _openStopSearch,
                icon: const Icon(Icons.search_rounded, size: 20),
                label: Text('Cerca e aggiungi fermata', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kRomagnaPrimary,
                  side: BorderSide(color: kRomagnaPrimary),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'In elenco',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kRomagnaDarkGray.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 6),
              _favoriteStopsList(),
            ],
          ),
          const SizedBox(height: 14),
          _sectionCard(
            icon: Icons.directions_bus_outlined,
            title: 'Linee preferite',
            children: [
              _bacinoDropdown(
                value: _lineeBacino,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _lineeBacino = v;
                    _lineDropdownValue = null;
                  });
                },
              ),
              const SizedBox(height: 10),
              if (!_lineeLoaded)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: kRomagnaPrimary),
                    ),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _lineDropdownValue,
                  isExpanded: true,
                  hint: Text(
                    'Seleziona una linea',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: kRomagnaDarkGray.withValues(alpha: 0.45),
                    ),
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  style: GoogleFonts.inter(fontSize: 14, color: kRomagnaDarkGray),
                  items:
                      linee
                          .map(
                            (r) => DropdownMenuItem<String>(
                              value: r.routeId,
                              child: Text(
                                'Linea ${r.linea} · ${r.area}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (routeId) {
                    if (routeId == null) return;
                    RomagnaLineaRow? row;
                    for (final r in linee) {
                      if (r.routeId == routeId) {
                        row = r;
                        break;
                      }
                    }
                    if (row == null) return;
                    setState(() => _lineDropdownValue = routeId);
                    _addLine(row);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _lineDropdownValue = null);
                    });
                  },
                ),
              const SizedBox(height: 14),
              Text(
                'In elenco',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kRomagnaDarkGray.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 6),
              _favoriteLinesList(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bacinoDropdown({required String value, required ValueChanged<String?> onChanged}) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Bacino',
        labelStyle: GoogleFonts.inter(fontSize: 13, color: kRomagnaDarkGray.withValues(alpha: 0.7)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      style: GoogleFonts.inter(fontSize: 14, color: kRomagnaDarkGray),
      items:
          kBaciniOrdine
              .map(
                (b) => DropdownMenuItem<String>(
                  value: b,
                  child: Text(bacinoTitolo(b), overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
      onChanged: onChanged,
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: kRomagnaPrimary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: kRomagnaDarkGray,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _favoriteStopsList() {
    if (_favoriteStops.isEmpty) {
      return Text(
        'Nessuna fermata. Usa «Cerca e aggiungi fermata».',
        style: GoogleFonts.inter(fontSize: 13, color: kRomagnaDarkGray.withValues(alpha: 0.5)),
      );
    }
    return Column(
      children: [
        for (final e in _favoriteStops) ...[
          _dismissTile(
            title: transitStopNameForDisplay(e.pin.stopName),
            subtitle: [
              if (e.pin.comune.isNotEmpty) e.pin.comune,
              e.bacinoUpper,
            ].join(' · '),
            onRemove: () => setState(() => _favoriteStops.remove(e)),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _favoriteLinesList() {
    if (_favoriteLines.isEmpty) {
      return Text(
        'Nessuna linea. Scegli dal menu «Seleziona una linea».',
        style: GoogleFonts.inter(fontSize: 13, color: kRomagnaDarkGray.withValues(alpha: 0.5)),
      );
    }
    return Column(
      children: [
        for (final e in _favoriteLines) ...[
          _dismissTile(
            title: 'Linea ${e.row.linea}',
            subtitle: '${e.row.area} · ${e.row.bacino}',
            onRemove: () => setState(() => _favoriteLines.remove(e)),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _dismissTile({
    required String title,
    required String subtitle,
    required VoidCallback onRemove,
  }) {
    return Material(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: kRomagnaDarkGray),
                ),
                subtitle: Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 12, color: kRomagnaDarkGray.withValues(alpha: 0.55)),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Rimuovi',
              onPressed: onRemove,
              icon: Icon(Icons.close_rounded, color: kRomagnaDarkGray.withValues(alpha: 0.55)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopSearchSheet extends StatefulWidget {
  const _StopSearchSheet({
    required this.bacinoLabel,
    required this.loadPins,
    required this.onPick,
  });

  final String bacinoLabel;
  final Future<List<TransitStopPin>> Function() loadPins;
  final void Function(TransitStopPin pin) onPick;

  @override
  State<_StopSearchSheet> createState() => _StopSearchSheetState();
}

class _StopSearchSheetState extends State<_StopSearchSheet> {
  final _controller = TextEditingController();
  List<TransitStopPin> _all = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pins = await widget.loadPins();
      if (!mounted) return;
      setState(() {
        _all = pins;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossibile caricare le fermate.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _controller.text;
    final ranked = filterAndRankTransitStops(_all, q);
    final shown = ranked.length > 80 ? ranked.sublist(0, 80) : ranked;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Fermate · ${widget.bacinoLabel}',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Cerca per nome o codice (min. 2 caratteri)',
                  hintStyle: GoogleFonts.inter(fontSize: 14),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
                style: GoogleFonts.inter(fontSize: 15),
              ),
            ),
            if (_loading)
              Expanded(child: Center(child: CircularProgressIndicator(color: kRomagnaPrimary)))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Text(_error!, style: GoogleFonts.inter(color: kRomagnaDarkGray.withValues(alpha: 0.65))),
                ),
              )
            else if (q.trim().length < 2)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Digita almeno 2 caratteri per cercare tra le fermate del bacino.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.35,
                        color: kRomagnaDarkGray.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
              )
            else if (shown.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'Nessun risultato.',
                    style: GoogleFonts.inter(color: kRomagnaDarkGray.withValues(alpha: 0.55)),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: shown.length,
                  itemBuilder: (c, i) {
                    final pin = shown[i];
                    final name = transitStopNameForDisplay(pin.stopName);
                    final sub = [
                      if (pin.stopId.isNotEmpty) pin.stopId,
                      if (pin.comune.isNotEmpty) pin.comune,
                    ].join(' · ');
                    return ListTile(
                      title: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle:
                          sub.isEmpty
                              ? null
                              : Text(sub, style: GoogleFonts.inter(fontSize: 12, color: Colors.black54)),
                      onTap: () => widget.onPick(pin),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
