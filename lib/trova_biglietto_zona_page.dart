// Schermata «Trova biglietto»: Trova Zona come su startromagna.it/trova-zona-3/

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'romagna_brand.dart';
import 'start_trova_zona_api.dart';

/// Nome località senza il codice zona ripetuto in coda (es. "Acquapartita 884" → "Acquapartita").
String _trovaZonaNomeLocalita(TrovaZonaOption o) {
  final t = o.label.trim();
  final c = o.code.trim();
  if (c.isEmpty) return t;
  final suffix = RegExp(r'\s+' + RegExp.escape(c) + r'$');
  final stripped = t.replaceFirst(suffix, '').trim();
  return stripped.isEmpty ? t : stripped;
}

/// Nome località con maiuscole/minuscole normalizzate (es. «Budrio di cesena» → «Budrio di Cesena»).
String _trovaZonaNomeLocalitaDisplay(TrovaZonaOption o) =>
    _trovaZonaTitleCaseNome(_trovaZonaNomeLocalita(o));

String _trovaZonaDisplayStringSelezionata(TrovaZonaOption o) {
  final nome = _trovaZonaNomeLocalitaDisplay(o);
  return '$nome - Zona ${o.code}';
}

const Set<String> _italianTitleCaseParticles = {
  'a',
  'ad',
  'al',
  'allo',
  'alla',
  'ai',
  'agli',
  'alle',
  'con',
  'da',
  'dal',
  'dallo',
  'dalla',
  'dai',
  'dagli',
  'dalle',
  'de',
  'degli',
  'dei',
  'del',
  'dell',
  'della',
  'delle',
  'di',
  'e',
  'ed',
  'i',
  'il',
  'in',
  'lo',
  'la',
  'le',
  'gli',
  'nel',
  'nello',
  'nella',
  'nei',
  'negli',
  'nelle',
  'su',
  'sul',
  'sullo',
  'sulla',
  'sui',
  'sugli',
  'sulle',
  'per',
};

String _trovaZonaCapitalizeWord(String word) {
  if (word.isEmpty) return word;
  if (word.contains("'")) {
    return word
        .split("'")
        .map((part) {
          if (part.isEmpty) return part;
          final lower = part.toLowerCase();
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join("'");
  }
  if (word.contains('-')) {
    return word.split('-').map(_trovaZonaCapitalizeWord).join('-');
  }
  final lower = word.toLowerCase();
  if (word.length <= 4 &&
      RegExp(r'^[A-Z0-9\.]+$').hasMatch(word) &&
      word == word.toUpperCase()) {
    return word;
  }
  if (lower.isEmpty) return word;
  return lower[0].toUpperCase() + lower.substring(1);
}

String _trovaZonaTitleCaseNome(String input) {
  final t = input.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.isEmpty) return input;
  final words = t.split(' ');
  final out = <String>[];
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    final particle = w.toLowerCase();
    if (i > 0 && _italianTitleCaseParticles.contains(particle)) {
      out.add(particle);
    } else {
      out.add(_trovaZonaCapitalizeWord(w));
    }
  }
  return out.join(' ');
}

String _trovaZonaNormalizeSearchText(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[\s\.]+'), '');

/// Varianti equivalenti per prefissi «S.» / «San» / «Santo» / «Santa» in ricerca.
const List<String> _saintSearchPrefixAliases = [
  's',
  's.',
  'st',
  'st.',
  'san',
  'santo',
  'santa',
  "sant'",
];

final RegExp _saintPrefixAtStart = RegExp(
  r"^(s\.?|st\.?|san|santo|santa|sant'?)\s*",
  caseSensitive: false,
);

/// «S.Piero» → «S. Piero» prima di indicizzare o confrontare.
String _trovaZonaPreprocessSearchText(String text) {
  var s = text.trim();
  s = s.replaceAllMapped(
    RegExp(r'(?<=\b[sS])\.(?=[\p{L}])', unicode: true),
    (_) => '. ',
  );
  return s.replaceAll(RegExp(r'\s+'), ' ');
}

bool _isSaintPrefixToken(String token) {
  final t = token.trim().toLowerCase();
  if (t.isEmpty) return false;
  if (t.startsWith("sant'")) return true;
  final bare = t.replaceAll('.', '');
  return _saintSearchPrefixAliases.contains(t) ||
      _saintSearchPrefixAliases.contains(bare) ||
      {'s', 'st', 'san', 'santo', 'santa'}.contains(bare);
}

/// Genera forme alternative con tutti i prefissi santo (es. «S. Piero» → anche «San Piero»).
List<String> _trovaZonaSaintSearchVariants(String text) {
  final pre = _trovaZonaPreprocessSearchText(text);
  final variants = <String>{pre};
  final m = _saintPrefixAtStart.firstMatch(pre.toLowerCase());
  if (m == null) return variants.toList();
  final rest = pre.substring(m.end).trim();
  if (rest.isEmpty) return variants.toList();
  for (final prefix in _saintSearchPrefixAliases) {
    variants.add('$prefix $rest');
    variants.add('$prefix$rest');
  }
  return variants.toList();
}

String _trovaZonaSearchHaystack(TrovaZonaOption o) {
  final chunks = <String>[o.code, o.label];
  for (final base in [
    _trovaZonaNomeLocalita(o),
    _trovaZonaNomeLocalitaDisplay(o),
    o.label,
  ]) {
    chunks.add(base);
    chunks.addAll(_trovaZonaSaintSearchVariants(base));
  }
  return _trovaZonaNormalizeSearchText(chunks.join(' '));
}

bool _trovaZonaTokenMatchesHaystack(String token, String haystack) {
  final pre = _trovaZonaPreprocessSearchText(token);
  final tNorm = _trovaZonaNormalizeSearchText(pre);
  if (tNorm.isNotEmpty && haystack.contains(tNorm)) return true;
  if (_isSaintPrefixToken(pre)) {
    for (final alias in _saintSearchPrefixAliases) {
      if (haystack.contains(_trovaZonaNormalizeSearchText(alias))) {
        return true;
      }
    }
  }
  return false;
}

bool _trovaZonaOptionMatchesQuery(TrovaZonaOption o, String queryRaw) {
  final q = _trovaZonaPreprocessSearchText(queryRaw);
  if (q.isEmpty) return true;
  final haystack = _trovaZonaSearchHaystack(o);
  final qNorm = _trovaZonaNormalizeSearchText(q);
  if (qNorm.isNotEmpty && haystack.contains(qNorm)) return true;
  for (final variant in _trovaZonaSaintSearchVariants(q)) {
    final vNorm = _trovaZonaNormalizeSearchText(variant);
    if (vNorm.isNotEmpty && haystack.contains(vNorm)) return true;
  }
  final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  if (tokens.isEmpty) return true;
  return tokens.every((t) => _trovaZonaTokenMatchesHaystack(t, haystack));
}

/// Prima lettera alfabetica maiuscola, resto minuscolo (come da mostrare in elenco titoli).
String _titoloZonaPrimaLetteraMaiuscola(String s) {
  final t = s.trim();
  if (t.isEmpty) return s;
  final lower = t.toLowerCase();
  final m = RegExp(r'\p{L}', unicode: true).firstMatch(lower);
  String out;
  if (m != null) {
    final i = m.start;
    final seg = m.group(0)!;
    out =
        lower.substring(0, i) +
        seg.toUpperCase() +
        lower.substring(i + seg.length);
  } else if (lower.isEmpty) {
    out = s;
  } else {
    out = lower[0].toUpperCase() + lower.substring(1);
  }
  return out
      .replaceAll(RegExp(r'smartpass', caseSensitive: false), 'SmartPass')
      .replaceAll(RegExp(r'smart pass', caseSensitive: false), 'SmartPass');
}

/// Gallo: Romagna / SmartPass nel nome (stessa logica di [_titoloLeadingIcon]).
bool _trovaZonaTitoloIconaGallo(String nome) {
  final n = nome.toLowerCase();
  if (n.contains('romagna')) return true;
  return RegExp(r'smart\s*pass').hasMatch(n);
}

/// Icona tessera: abbonamenti, multicorsa, ecc.
bool _trovaZonaTitoloIconaTessera(String nome, String validitaGrezza) {
  final s = '${nome.toLowerCase()} ${validitaGrezza.trim()}'.trim();
  if (RegExp(r'\b(biglietto|corsa\s+semplice)\b').hasMatch(s) &&
      !RegExp(
        r'\b(abbonamento|abbonamenti|mensile|annuale|trimestrale|semestrale|'
        r'smart\s*pass|metropass|multipass|multipasse|io\s*viaggio|'
        r'integrazione\s+abbonamento|abbonamento\s+integrazione|carnet|'
        r'multicorsa|borsellino|pass)\b',
      ).hasMatch(s)) {
    return false;
  }
  if (RegExp(
    r'\b(abbonamento|abbonamenti|mensile|annuale|trimestrale|semestrale|'
    r'smart\s*pass|metropass|multipass|multipasse|io\s*viaggio|'
    r'integrazione\s+abbonamento|abbonamento\s+integrazione|carnet|'
    r'multicorsa|borsellino)\b',
  ).hasMatch(s)) {
    return true;
  }
  if (RegExp(r'\bpass\b').hasMatch(s) &&
      !RegExp(r'\bbiglietto\b').hasMatch(s)) {
    return true;
  }
  return false;
}

/// 0 biglietto · 1 tessera · 2 gallo.
int _trovaZonaGruppoOrdineIconaTitolo(TrovaZonaPrezzoRow row) {
  final nome = row.descrizione.trim();
  if (_trovaZonaTitoloIconaGallo(nome)) return 2;
  if (_trovaZonaTitoloIconaTessera(nome, row.validita)) return 1;
  return 0;
}

List<TrovaZonaPrezzoRow> _trovaZonaOrdinaRighePerIcona(
  List<TrovaZonaPrezzoRow> righe,
) {
  final out = List<TrovaZonaPrezzoRow>.from(righe);
  out.sort((a, b) {
    final ga = _trovaZonaGruppoOrdineIconaTitolo(a);
    final gb = _trovaZonaGruppoOrdineIconaTitolo(b);
    if (ga != gb) return ga.compareTo(gb);
    return a.descrizione.toLowerCase().compareTo(b.descrizione.toLowerCase());
  });
  return out;
}

({Color fill, Color border, Color foreground}) _trovaZonaPillPalette(
  TrovaZonaBacino bacino,
) {
  switch (bacino) {
    case TrovaZonaBacino.ra:
      return (
        fill: kRomagnaPrimary.withValues(alpha: 0.12),
        border: kRomagnaPrimary.withValues(alpha: 0.38),
        foreground: kRomagnaPrimary,
      );
    case TrovaZonaBacino.fc:
      const g = Color(0xFF059669);
      return (
        fill: g.withValues(alpha: 0.12),
        border: g.withValues(alpha: 0.42),
        foreground: const Color(0xFF047857),
      );
    case TrovaZonaBacino.rn:
      return (
        fill: const Color(0xFFFFE4E6),
        border: const Color(0xFFFFAAB4),
        foreground: const Color(0xFFC62828),
      );
  }
}

Widget _trovaZonaPillCodice(String code, TrovaZonaBacino bacino) {
  final p = _trovaZonaPillPalette(bacino);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: p.fill,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: p.border),
    ),
    child: Text(
      code,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
        color: p.foreground,
      ),
    ),
  );
}

class TrovaBigliettoZonaPage extends StatefulWidget {
  const TrovaBigliettoZonaPage({super.key});

  @override
  State<TrovaBigliettoZonaPage> createState() => _TrovaBigliettoZonaPageState();
}

class _TrovaBigliettoZonaPageState extends State<TrovaBigliettoZonaPage> {
  late final http.Client _http;

  /// Tap fuori da campo + elenco partenza → chiude tastiera.
  final Object _trovaZonaSearchTapGroup = Object();

  final TextEditingController _partenzaCtrl = TextEditingController();
  final FocusNode _partenzaFocus = FocusNode();
  final ScrollController _pageScroll = ScrollController();
  final GlobalKey _partenzaAnchorKey = GlobalKey();

  Map<TrovaZonaBacino, List<TrovaZonaOption>>? _partenzePerBacino;
  bool _loadingPartenze = true;
  String? _errorePartenze;

  TrovaZonaBacino _bacino = TrovaZonaBacino.fc;
  TrovaZonaOption? _partenza;
  List<TrovaZonaOption> _arrivi = [];
  bool _loadingArrivi = false;
  String? _erroreArrivi;
  TrovaZonaOption? _arrivo;

  TrovaZonaPrezziResult? _risultato;
  bool _loadingPrezzi = false;
  String? _errorePrezzi;

  @override
  void initState() {
    super.initState();
    _http = http.Client();
    _partenzaFocus.addListener(_onPartenzaFocusChanged);
    _caricaPartenze();
  }

  void _onPartenzaFocusChanged() {
    if (_partenzaFocus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _partenzaAnchorKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.02,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _partenzaFocus.removeListener(_onPartenzaFocusChanged);
    _partenzaCtrl.dispose();
    _partenzaFocus.dispose();
    _pageScroll.dispose();
    _http.close();
    super.dispose();
  }

  Future<void> _caricaPartenze() async {
    setState(() {
      _loadingPartenze = true;
      _errorePartenze = null;
    });
    try {
      final m = await fetchTrovaZonaPartenze(
        client: _http,
      ).timeout(const Duration(seconds: 30));
      if (!mounted) return;
      // clear() non va dentro setState: può notificare listener e far fallire l’aggiornamento
      // lasciando _loadingPartenze a true (rotella infinita).
      try {
        _partenzaCtrl.clear();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _partenzePerBacino = m;
        _loadingPartenze = false;
        _partenza = null;
        _arrivi = [];
        _arrivo = null;
        _risultato = null;
        _errorePrezzi = null;
        _erroreArrivi = null;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _loadingPartenze = false;
        _errorePartenze =
            'Connessione troppo lenta o server non raggiungibile. '
            'Riprova tra poco.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPartenze = false;
        _errorePartenze =
            'Impossibile caricare le zone di partenza. '
            'Riprova tra poco o aggiorna l\'app.';
      });
    }
  }

  void _safeClearPartenzaField() {
    try {
      _partenzaCtrl.clear();
    } catch (_) {}
  }

  void _resetJourneyState() {
    _partenza = null;
    _arrivi = [];
    _arrivo = null;
    _risultato = null;
    _errorePrezzi = null;
    _erroreArrivi = null;
  }

  void _clearPartenza() {
    _partenzaFocus.unfocus();
    _safeClearPartenzaField();
    setState(() {
      _resetJourneyState();
    });
  }

  void _clearArrivo() {
    setState(() {
      _arrivo = null;
      _risultato = null;
      _errorePrezzi = null;
    });
  }

  Future<void> _apriSelettoreArrivo() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_arrivi.isEmpty) return;

    final scelta = await showModalBottomSheet<TrovaZonaOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (sheetCtx) => _ArrivoZonaPickerSheet(
            opzioni: List<TrovaZonaOption>.from(_arrivi),
            bacino: _bacino,
          ),
    );

    if (!mounted || scelta == null) return;
    setState(() {
      _arrivo = scelta;
      _risultato = null;
      _errorePrezzi = null;
    });
  }

  Future<void> _caricaArrivi() async {
    final p = _partenza;
    if (p == null) return;
    setState(() {
      _loadingArrivi = true;
      _erroreArrivi = null;
      _arrivo = null;
      _risultato = null;
      _errorePrezzi = null;
    });
    try {
      final list = await fetchZoneArrivo(
        codicePartenza: p.code,
        bacino: _bacino,
        client: _http,
      );
      if (!mounted) return;
      setState(() {
        _arrivi = list;
        _loadingArrivi = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingArrivi = false;
        _erroreArrivi =
            'Impossibile caricare le zone di arrivo. ${e.toString()}';
      });
    }
  }

  Future<void> _trovaTariffa() async {
    final p = _partenza;
    final a = _arrivo;
    if (p == null || a == null) {
      setState(() {
        _errorePrezzi = 'Seleziona zona di partenza e zona di arrivo.';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loadingPrezzi = true;
      _errorePrezzi = null;
      _risultato = null;
    });
    try {
      final r = await fetchZonePrezzi(
        partenza: p.code,
        arrivo: a.code,
        bacino: _bacino,
        client: _http,
      );
      if (!mounted) return;
      setState(() {
        _risultato = r;
        _loadingPrezzi = false;
      });
    } on TrovaZonaNessunRisultato catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPrezzi = false;
        _errorePrezzi = e.messaggio;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPrezzi = false;
        _errorePrezzi =
            'Impossibile calcolare la tariffa per questa tratta. '
            'Riprova più tardi o consulta le tariffe in Informazioni biglietti.';
      });
    }
  }

  List<TrovaZonaOption> get _partenzeCorrenti =>
      _partenzePerBacino?[_bacino] ?? const <TrovaZonaOption>[];

  List<TrovaZonaOption> _partenzaSuggerimentiFiltrati() {
    final list = _partenzeCorrenti;
    final q = _partenzaCtrl.text.trim();
    if (q.isEmpty) {
      return list.take(48).toList();
    }
    return list
        .where((o) => _trovaZonaOptionMatchesQuery(o, q))
        .take(80)
        .toList();
  }

  double _altezzaElencoPartenza(BuildContext context) {
    final mq = MediaQuery.of(context);
    final avail = mq.size.height - mq.padding.vertical - mq.viewInsets.bottom;
    return (avail * 0.4).clamp(176.0, 360.0);
  }

  Widget _buildElencoPartenza(BuildContext context) {
    final sug = _partenzaSuggerimentiFiltrati();
    if (sug.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Nessuna zona corrispondente.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: kRomagnaDarkGray.withValues(alpha: 0.55),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: sug.length,
      separatorBuilder:
          (_, __) => Divider(
            height: 1,
            thickness: 1,
            indent: 12,
            endIndent: 12,
            color: kRomagnaDarkGray.withValues(alpha: 0.08),
          ),
      itemBuilder: (context, index) {
        final o = sug[index];
        return InkWell(
          onTap: () {
            setState(() {
              _partenza = o;
              _partenzaCtrl.text = _trovaZonaDisplayStringSelezionata(o);
            });
            _partenzaFocus.unfocus();
            _caricaArrivi();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _trovaZonaPillCodice(o.code, _bacino),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _trovaZonaNomeLocalitaDisplay(o),
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: kRomagnaDarkGray,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Zona ${o.code}',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          height: 1.2,
                          color: kRomagnaDarkGray.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Trova biglietto',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFFAFAFA),
      resizeToAvoidBottomInset: true,
      body: RefreshIndicator(
        onRefresh: _caricaPartenze,
        child: ListView(
          controller: _pageScroll,
          padding: EdgeInsets.fromLTRB(16, 12, 16, 28).add(
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          children: [
            _helpCard(),
            const SizedBox(height: 16),
            if (_loadingPartenze)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorePartenze != null)
              _errorCard(_errorePartenze!)
            else ...[
              _sectionTitle('Bacino'),
              const SizedBox(height: 8),
              SegmentedButton<TrovaZonaBacino>(
                segments: [
                  for (final b in TrovaZonaBacino.values)
                    ButtonSegment<TrovaZonaBacino>(
                      value: b,
                      label: Text(
                        b == TrovaZonaBacino.fc
                            ? 'FC'
                            : b == TrovaZonaBacino.ra
                            ? 'RA'
                            : 'RN',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      tooltip: b.label,
                    ),
                ],
                selected: {_bacino},
                onSelectionChanged: (s) {
                  _safeClearPartenzaField();
                  setState(() {
                    _bacino = s.first;
                    _resetJourneyState();
                  });
                  _partenzaFocus.unfocus();
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return kRomagnaDarkGray;
                  }),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return kRomagnaPrimary;
                    }
                    return Colors.white;
                  }),
                ),
              ),
              const SizedBox(height: 20),
              _sectionTitle('Zona di partenza'),
              const SizedBox(height: 6),
              Text(
                'Elenco delle zone per il bacino scelto',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  height: 1.35,
                  color: kRomagnaDarkGray.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 10),
              TapRegion(
                key: _partenzaAnchorKey,
                groupId: _trovaZonaSearchTapGroup,
                onTapOutside: (_) => _partenzaFocus.unfocus(),
                child: Column(
                  key: ValueKey<TrovaZonaBacino>(_bacino),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _partenzaCtrl,
                      focusNode: _partenzaFocus,
                      textInputAction: TextInputAction.search,
                      scrollPadding: EdgeInsets.fromLTRB(
                        16,
                        120,
                        16,
                        32 +
                            MediaQuery.viewInsetsOf(context).bottom +
                            _altezzaElencoPartenza(context),
                      ),
                      onChanged: (t) {
                        if (_partenza != null) {
                          final exp = _trovaZonaDisplayStringSelezionata(
                            _partenza!,
                          );
                          if (t.trim() != exp.trim()) {
                            setState(() {
                              _partenza = null;
                              _arrivi = [];
                              _arrivo = null;
                              _risultato = null;
                              _errorePrezzi = null;
                            });
                          }
                        }
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: 'Cerca zona per nome o codice',
                        hintStyle: GoogleFonts.inter(
                          color: kRomagnaDarkGray.withValues(alpha: 0.45),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: kRomagnaDarkGray.withValues(alpha: 0.12),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: kRomagnaPrimary,
                            width: 1.4,
                          ),
                        ),
                        suffixIcon:
                            (_partenza != null || _partenzaCtrl.text.isNotEmpty)
                                ? IconButton(
                                  tooltip: 'Cancella selezione',
                                  onPressed: _clearPartenza,
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 22,
                                    color: kRomagnaDarkGray.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                )
                                : null,
                      ),
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    if (_partenzaFocus.hasFocus) ...[
                      const SizedBox(height: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: kRomagnaDarkGray.withValues(alpha: 0.1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: _altezzaElencoPartenza(context),
                            child: _buildElencoPartenza(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _sectionTitle('Zona di arrivo (tutte le zone)'),
              const SizedBox(height: 10),
              if (_partenza == null)
                Text(
                  'Scegli prima la partenza',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: kRomagnaDarkGray.withValues(alpha: 0.5),
                  ),
                )
              else if (_loadingArrivi)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_erroreArrivi != null)
                _errorCard(_erroreArrivi!)
              else
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _apriSelettoreArrivo,
                    child: InputDecorator(
                      isEmpty: _arrivo == null,
                      decoration: InputDecoration(
                        hintText: 'Scegli zona…',
                        hintStyle: GoogleFonts.inter(
                          color: kRomagnaDarkGray.withValues(alpha: 0.45),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: kRomagnaDarkGray.withValues(alpha: 0.12),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: kRomagnaPrimary,
                            width: 1.4,
                          ),
                        ),
                        contentPadding: const EdgeInsets.fromLTRB(
                          14,
                          16,
                          4,
                          16,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_arrivo != null)
                              IconButton(
                                tooltip: 'Cancella selezione',
                                onPressed: _clearArrivo,
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 22,
                                  color: kRomagnaDarkGray.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 26,
                                color: kRomagnaDarkGray.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      child: Text(
                        _arrivo == null
                            ? ''
                            : _trovaZonaDisplayStringSelezionata(_arrivo!),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: kRomagnaDarkGray,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loadingPrezzi ? null : _trovaTariffa,
                  icon:
                      _loadingPrezzi
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.search_rounded),
                  label: Text(
                    'Trova tariffa zone',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: kRomagnaPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (_errorePrezzi != null) ...[
                const SizedBox(height: 14),
                _errorCard(_errorePrezzi!),
              ],
              if (_risultato != null) ...[
                const SizedBox(height: 20),
                _risultatoCard(_risultato!),
              ],
              const SizedBox(height: 20),
              Text(
                'Dati tariffari da Start Romagna SpA. '
                'In caso di dubbio verifica sui canali ufficiali o contatta il Servizio Clienti.',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  height: 1.4,
                  color: kRomagnaDarkGray.withValues(alpha: 0.45),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: kRomagnaDarkGray,
      ),
    );
  }

  Widget _helpCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: kRomagnaDarkGray.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  size: 22,
                  color: kRomagnaPrimary.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 8),
                Text(
                  'Come usare il Trova Zona',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: kRomagnaDarkGray,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Prima di acquistare un titolo di viaggio, verifica quante zone '
              'attraversi tra partenza e arrivo.',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                height: 1.45,
                color: kRomagnaDarkGray.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            _helpBullet(
              'Scegli il bacino (Forlì-Cesena, Ravenna, Rimini), poi la zona di partenza e la zona di arrivo.',
            ),
            _helpBullet(
              'Le zone di arrivo proposte dipendono dalla partenza selezionata.',
            ),
            _helpBullet(
              'Seleziona «Trova tariffa zone» per scoprire quante zone vengono attraversate '
              'e quali titoli di viaggio sono indicati per il tuo viaggio.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _helpBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.45,
              color: kRomagnaPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.45,
                color: kRomagnaDarkGray.withValues(alpha: 0.68),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String msg) {
    return Card(
      elevation: 0,
      color: const Color(0xFFFFF1F2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFFECACA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFB91C1C)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  height: 1.4,
                  color: const Color(0xFFB91C1C),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Nome, validità e prezzo: la validità si mostra sempre se presente sul sito,
  /// salvo duplicato identico al nome (stesso testo, stesso significato).
  ({String nome, String? validita, String prezzo}) _titoloIndicatoParti(
    TrovaZonaPrezzoRow row,
  ) {
    var nome = row.descrizione.trim();
    var val = row.validita.trim();
    final prezzo = row.prezzo.trim();

    final vl0 = val.toLowerCase();
    if (vl0.startsWith('validità:') || vl0.startsWith('validita:')) {
      final i = val.indexOf(':');
      if (i >= 0) {
        val = val.substring(i + 1).trim();
      }
    }

    String? validitaOut;
    if (val.isNotEmpty) {
      final nl = nome.toLowerCase();
      final vl = val.toLowerCase();
      if (nl != vl) {
        validitaOut = val;
      }
    }

    return (nome: nome, validita: validitaOut, prezzo: prezzo);
  }

  bool _titoloIndicatoRomagna(String nome) => _trovaZonaTitoloIconaGallo(nome);

  bool _titoloIndicatoAbbonamento(String nome, String? validitaGrezza) =>
      _trovaZonaTitoloIconaTessera(nome, validitaGrezza ?? '');

  Widget _titoloLeadingIcon(TrovaZonaPrezzoRow row, String nome) {
    const w = 40.0;
    if (_titoloIndicatoRomagna(nome)) {
      return SizedBox(
        width: w,
        child: const Center(
          child: Text('🐓', style: TextStyle(fontSize: 22, height: 1.1)),
        ),
      );
    }
    final sub = _titoloIndicatoAbbonamento(nome, row.validita);
    return SizedBox(
      width: w,
      child: Center(
        child: Icon(
          sub
              ? Icons.card_membership_outlined
              : Icons.confirmation_number_outlined,
          color: kRomagnaPrimary.withValues(alpha: 0.92),
          size: 26,
        ),
      ),
    );
  }

  List<Widget> _childrenElencoTitoliZona(TrovaZonaPrezziResult r) {
    final ord = _trovaZonaOrdinaRighePerIcona(r.righe);
    return [
      for (var i = 0; i < ord.length; i++) ...[
        if (i > 0)
          Divider(height: 20, color: kRomagnaDarkGray.withValues(alpha: 0.08)),
        _prezzoRowTile(ord[i]),
      ],
    ];
  }

  Widget _risultatoCard(TrovaZonaPrezziResult r) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: kRomagnaPrimary.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.route_rounded,
                  color: kRomagnaPrimary.withValues(alpha: 0.95),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Zone attraversate: ${r.zoneAttraversate}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: kRomagnaDarkGray,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Titoli indicati:',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: kRomagnaDarkGray.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 12),
            ..._childrenElencoTitoliZona(r),
          ],
        ),
      ),
    );
  }

  Widget _prezzoRowTile(TrovaZonaPrezzoRow row) {
    final p = _titoloIndicatoParti(row);
    final validitaVis = p.validita ?? '';
    final grey = kRomagnaDarkGray.withValues(alpha: 0.52);
    final nomeDisp =
        p.nome.isEmpty ? '—' : _titoloZonaPrimaLetteraMaiuscola(p.nome);
    final valDisp =
        validitaVis.isEmpty
            ? ''
            : _titoloZonaPrimaLetteraMaiuscola(validitaVis);
    final prezzoDisp =
        p.prezzo.isEmpty ? '—' : _titoloZonaPrimaLetteraMaiuscola(p.prezzo);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _titoloLeadingIcon(row, row.descrizione.trim()),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nomeDisp,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.3,
                    color: kRomagnaPrimary,
                  ),
                ),
                Text(
                  valDisp.isEmpty ? ' ' : valDisp,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w400,
                    fontSize: 12.5,
                    height: 1.35,
                    color: valDisp.isEmpty ? Colors.transparent : grey,
                  ),
                ),
                Text(
                  prezzoDisp,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.35,
                    color: kRomagnaDarkGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Foglio scelta zona arrivo: controller creato in [initState] e eliminato in
/// [dispose] dopo lo smontaggio della route (evita "used after disposed" al focus).
class _ArrivoZonaPickerSheet extends StatefulWidget {
  const _ArrivoZonaPickerSheet({required this.opzioni, required this.bacino});

  final List<TrovaZonaOption> opzioni;
  final TrovaZonaBacino bacino;

  @override
  State<_ArrivoZonaPickerSheet> createState() => _ArrivoZonaPickerSheetState();
}

class _ArrivoZonaPickerSheetState extends State<_ArrivoZonaPickerSheet> {
  late final TextEditingController _filter;

  @override
  void initState() {
    super.initState();
    _filter = TextEditingController();
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPad = mq.viewInsets.bottom;
    final screenH = mq.size.height;
    final maxH = (screenH * 0.72).clamp(280.0, 540.0);

    final q = _filter.text.trim();
    final filtered =
        q.isEmpty
            ? List<TrovaZonaOption>.from(widget.opzioni)
            : widget.opzioni
                .where((o) => _trovaZonaOptionMatchesQuery(o, q))
                .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: SizedBox(
        height: maxH,
        width: double.infinity,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          'Zona di arrivo',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: kRomagnaDarkGray,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Chiudi',
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: kRomagnaDarkGray.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _filter,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Cerca zona o località…',
                    hintStyle: GoogleFonts.inter(
                      color: kRomagnaDarkGray.withValues(alpha: 0.45),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: kRomagnaDarkGray.withValues(alpha: 0.12),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: kRomagnaPrimary,
                        width: 1.4,
                      ),
                    ),
                  ),
                  style: GoogleFonts.inter(fontSize: 14),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child:
                    filtered.isEmpty
                        ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Nessuna zona corrispondente.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: kRomagnaDarkGray.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        )
                        : ListView.separated(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.manual,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 12),
                          itemCount: filtered.length,
                          separatorBuilder:
                              (_, __) => Divider(
                                height: 1,
                                thickness: 1,
                                indent: 16,
                                endIndent: 16,
                                color: kRomagnaDarkGray.withValues(alpha: 0.08),
                              ),
                          itemBuilder: (ctx, i) {
                            final o = filtered[i];
                            return InkWell(
                              onTap: () => Navigator.pop(context, o),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _trovaZonaPillCodice(o.code, widget.bacino),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _trovaZonaNomeLocalitaDisplay(o),
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: kRomagnaDarkGray,
                                            ),
                                          ),
                                          Text(
                                            'Zona ${o.code}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: kRomagnaDarkGray
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
