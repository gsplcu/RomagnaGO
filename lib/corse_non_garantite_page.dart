// Corse non garantite — dati da servizi.startromagna.it (tabella HTML GridView1).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';

import 'romagna_brand.dart';

const String _kCorseNgOfficialUrl =
    'https://www.startromagna.it/corse-non-garantite/';
const String _kCorseNgBasePath = '/corsesoppresse/corsesopp';

/// Valori `param1` come nell’URL del form ASP.NET (vedi action `./corsesopp?param1=…`).
enum CorseNonGarantiteBacino {
  forliCesena(
    param1: 'Forli-Cesena',
    label: 'Forlì-Cesena',
    buttonFill: Color(0xFFE4F4E7),
    buttonBorder: Color(0xFF7BC48A),
  ),
  ravenna(
    param1: 'Ravenna',
    label: 'Ravenna',
    buttonFill: Color(0xFFE3F0FA),
    buttonBorder: Color(0xFF7EB8E0),
  ),
  rimini(
    param1: 'Rimini',
    label: 'Rimini',
    buttonFill: Color(0xFFFFE8D6),
    buttonBorder: Color(0xFFFFB47A),
  );

  const CorseNonGarantiteBacino({
    required this.param1,
    required this.label,
    required this.buttonFill,
    required this.buttonBorder,
  });

  final String param1;
  final String label;
  final Color buttonFill;
  final Color buttonBorder;
}

class CorseNonGarantiteRow {
  const CorseNonGarantiteRow({
    required this.linea,
    required this.inizio,
    required this.dalle,
    required this.fine,
    required this.alle,
    required this.data,
  });

  final String linea;
  final String inizio;
  final String dalle;
  final String fine;
  final String alle;
  final String data;
}

String _cellText(dynamic node) {
  return node.text.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Estrae le righe dalla tabella `#GridView1` della pagina servizi.
List<CorseNonGarantiteRow> parseCorseNonGarantiteHtml(String html) {
  final doc = html_parser.parse(html);
  final table = doc.getElementById('GridView1');
  if (table == null) return const [];
  final out = <CorseNonGarantiteRow>[];
  for (final tr in table.getElementsByTagName('tr')) {
    final tds = tr.getElementsByTagName('td');
    if (tds.length < 6) continue;
    out.add(
      CorseNonGarantiteRow(
        linea: _cellText(tds[0]),
        inizio: _cellText(tds[1]),
        dalle: _cellText(tds[2]),
        fine: _cellText(tds[3]),
        alle: _cellText(tds[4]),
        data: formatCorseNgDataBreve(_cellText(tds[5])),
      ),
    );
  }
  return out;
}

Future<List<CorseNonGarantiteRow>> fetchCorseNonGarantite({
  required DateTime giorno,
  required CorseNonGarantiteBacino bacino,
}) async {
  final y = giorno.year.toString().padLeft(4, '0');
  final m = giorno.month.toString().padLeft(2, '0');
  final d = giorno.day.toString().padLeft(2, '0');
  final uri = Uri.https(
    'servizi.startromagna.it',
    _kCorseNgBasePath,
    {'param1': bacino.param1, 'param2': '$y-$m-$d'},
  );
  final res = await http.get(
    uri,
    headers: const {
      'Accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
      'User-Agent': 'RomagnaGO/1.0 (corse non garantite)',
    },
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('HTTP ${res.statusCode}');
  }
  return parseCorseNonGarantiteHtml(res.body);
}

const List<String> _mesiIt = [
  '',
  'gennaio',
  'febbraio',
  'marzo',
  'aprile',
  'maggio',
  'giugno',
  'luglio',
  'agosto',
  'settembre',
  'ottobre',
  'novembre',
  'dicembre',
];

const List<String> _giorniIt = [
  '',
  'Lunedì',
  'Martedì',
  'Mercoledì',
  'Giovedì',
  'Venerdì',
  'Sabato',
  'Domenica',
];

String formatCorseNgDataItaliana(DateTime dt) {
  final dow = _giorniIt[dt.weekday];
  final mese = _mesiIt[dt.month];
  return '$dow ${dt.day} $mese';
}

/// Data da tabella servizi (es. 16-05-2026) → formato italiano 16/05/2026.
String formatCorseNgDataBreve(String raw) {
  return raw.trim().replaceAll('-', '/');
}

/// True se il testo linea (tabella servizi) si riferisce al Metromare.
bool isCorseNgLineaMetromare(String linea) {
  return linea.toLowerCase().contains('metromare');
}

/// Schermata elenco corse (si apre dal tap su un bacino). Tasto Indietro = AppBar.
class CorseNonGarantiteListaPage extends StatefulWidget {
  const CorseNonGarantiteListaPage({
    super.key,
    required this.giorno,
    required this.bacino,
  });

  final DateTime giorno;
  final CorseNonGarantiteBacino bacino;

  @override
  State<CorseNonGarantiteListaPage> createState() =>
      _CorseNonGarantiteListaPageState();
}

class _CorseNonGarantiteListaPageState extends State<CorseNonGarantiteListaPage> {
  late Future<List<CorseNonGarantiteRow>> _future;
  final Set<String> _lineeSelezionate = {};

  @override
  void initState() {
    super.initState();
    _future = fetchCorseNonGarantite(
      giorno: widget.giorno,
      bacino: widget.bacino,
    );
  }

  static List<String> _lineePresenti(List<CorseNonGarantiteRow> rows) {
    final linee = rows.map((r) => r.linea).toSet().toList();
    linee.sort(_compareLinea);
    return linee;
  }

  static int _compareLinea(String a, String b) {
    int key(String s) {
      final m = RegExp(r'^(\d+)').firstMatch(s.trim());
      if (m != null) return int.tryParse(m.group(1)!) ?? 1 << 20;
      return 1 << 20;
    }

    final ka = key(a);
    final kb = key(b);
    if (ka != kb) return ka.compareTo(kb);
    return a.compareTo(b);
  }

  Set<String> _selezioneValida(List<String> lineePresenti) =>
      _lineeSelezionate.where(lineePresenti.contains).toSet();

  bool _filtroTutte(List<String> lineePresenti) {
    final valide = _selezioneValida(lineePresenti);
    if (valide.isEmpty) return true;
    return lineePresenti.isNotEmpty && lineePresenti.every(valide.contains);
  }

  List<CorseNonGarantiteRow> _rowsFiltrate(
    List<CorseNonGarantiteRow> rows,
    List<String> lineePresenti,
  ) {
    if (_filtroTutte(lineePresenti)) return rows;
    final valide = _selezioneValida(lineePresenti);
    return rows.where((r) => valide.contains(r.linea)).toList();
  }

  void _onTutteTap() {
    setState(_lineeSelezionate.clear);
  }

  void _onLineaTap(String linea, List<String> lineePresenti) {
    setState(() {
      if (_lineeSelezionate.contains(linea)) {
        _lineeSelezionate.remove(linea);
        return;
      }
      _lineeSelezionate.add(linea);
      if (lineePresenti.every(_lineeSelezionate.contains)) {
        _lineeSelezionate.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = formatCorseNgDataItaliana(widget.giorno);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.bacino.label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: FutureBuilder<List<CorseNonGarantiteRow>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Impossibile caricare l’elenco.\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    height: 1.35,
                    color: Colors.red.shade800,
                  ),
                ),
              ),
            );
          }

          final rows = snap.data ?? const <CorseNonGarantiteRow>[];
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Non risultano corse non garantite per questo bacino e questa data.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.45,
                    color: kRomagnaDarkGray.withValues(alpha: 0.58),
                  ),
                ),
              ),
            );
          }

          final linee = _lineePresenti(rows);
          if (_lineeSelezionate.any((l) => !linee.contains(l))) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _lineeSelezionate.removeWhere((l) => !linee.contains(l));
              });
            });
          }

          final visibili = _rowsFiltrate(rows, linee);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (linee.length > 1)
                _CorseNgLineaFilterBar(
                  linee: linee,
                  tutteSelezionate: _filtroTutte(linee),
                  lineeSelezionate:
                      _filtroTutte(linee) ? const {} : _selezioneValida(linee),
                  onTutte: _onTutteTap,
                  onLinea: (l) => _onLineaTap(l, linee),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        4,
                        linee.length > 1 ? 8 : 12,
                        4,
                        10,
                      ),
                      child: Text(
                        dateStr,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: kRomagnaDarkGray.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                    if (visibili.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text(
                          'Nessuna corsa per le linee selezionate.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: kRomagnaDarkGray.withValues(alpha: 0.55),
                          ),
                        ),
                      )
                    else
                      for (var i = 0; i < visibili.length; i++) ...[
                        if (i > 0) const SizedBox(height: 18),
                        _CorseNgTripCard(row: visibili[i]),
                      ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Filtro linee: chip compatti, wrap, sempre visibile sopra lo scroll.
class _CorseNgLineaFilterBar extends StatelessWidget {
  const _CorseNgLineaFilterBar({
    required this.linee,
    required this.tutteSelezionate,
    required this.lineeSelezionate,
    required this.onTutte,
    required this.onLinea,
  });

  final List<String> linee;
  final bool tutteSelezionate;
  final Set<String> lineeSelezionate;
  final VoidCallback onTutte;
  final ValueChanged<String> onLinea;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: kRomagnaDarkGray.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _LineaChip(
              label: 'Tutte',
              selected: tutteSelezionate,
              onTap: onTutte,
            ),
            for (final linea in linee)
              _LineaChip(
                label: linea,
                selected: lineeSelezionate.contains(linea),
                metromare: isCorseNgLineaMetromare(linea),
                onTap: () => onLinea(linea),
              ),
          ],
        ),
      ),
    );
  }
}

class _LineaChip extends StatelessWidget {
  const _LineaChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.metromare = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool metromare;

  @override
  Widget build(BuildContext context) {
    final accent = metromare ? kMetromareRed : kRomagnaPrimary;
    return Material(
      color:
          selected
              ? accent.withValues(alpha: 0.14)
              : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  selected
                      ? accent.withValues(alpha: 0.55)
                      : kRomagnaDarkGray.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? accent : kRomagnaDarkGray.withValues(alpha: 0.72),
              height: 1.15,
            ),
          ),
        ),
      ),
    );
  }
}

class _CorseNgTripCard extends StatelessWidget {
  const _CorseNgTripCard({required this.row});

  final CorseNonGarantiteRow row;

  @override
  Widget build(BuildContext context) {
    final isMetromare = isCorseNgLineaMetromare(row.linea);
    final accent = isMetromare ? kMetromareRed : kRomagnaPrimary;
    final subtle = kRomagnaDarkGray.withValues(alpha: 0.45);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isMetromare
                  ? kMetromareRed.withValues(alpha: 0.35)
                  : kRomagnaPrimary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LINEA',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.15,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            row.linea,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: accent,
            ),
          ),
          const SizedBox(height: 18),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.inizio,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: kRomagnaDarkGray,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Orario',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: subtle,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        row.dalle,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kRomagnaDarkGray,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _DottedArrowBar(color: accent),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        row.fine,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: kRomagnaDarkGray,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Orario',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: subtle,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        row.alle,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kRomagnaDarkGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Data: ${row.data}',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: kRomagnaDarkGray.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Linea tratteggiata + freccia (stile mock).
class _DottedArrowBar extends StatelessWidget {
  const _DottedArrowBar({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SizedBox(
            height: 14,
            child: CustomPaint(
              painter: _HorizontalDotDashPainter(
                color: color.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
        Icon(Icons.arrow_forward_rounded, size: 22, color: color),
      ],
    );
  }
}

class _HorizontalDotDashPainter extends CustomPainter {
  _HorizontalDotDashPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1.15
          ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    const dash = 3.5;
    const gap = 4.5;
    var x = 0.0;
    while (x < size.width - 22) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _HorizontalDotDashPainter oldDelegate) =>
      oldDelegate.color != color;
}

class CorseNonGarantitePage extends StatelessWidget {
  const CorseNonGarantitePage({super.key});

  void _openLista(
    BuildContext context,
    DateTime giorno,
    CorseNonGarantiteBacino bacino,
  ) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => CorseNonGarantiteListaPage(giorno: giorno, bacino: bacino),
      ),
    );
  }

  Widget _bacinoRow(BuildContext context, DateTime giorno) {
    return Row(
      children: [
        for (final b in CorseNonGarantiteBacino.values) ...[
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: b == CorseNonGarantiteBacino.rimini ? 0 : 10,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openLista(context, giorno, b),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: b.buttonFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: b.buttonBorder, width: 1.2),
                    ),
                    child: Text(
                      b.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kRomagnaDarkGray,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _bloccoData(BuildContext context, DateTime giorno) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatCorseNgDataItaliana(giorno),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kRomagnaDarkGray,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          _bacinoRow(context, giorno),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = DateTime.now();
    final oggi = DateTime(n.year, n.month, n.day);
    final domani = oggi.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Corse non garantite',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Apri sul sito Start Romagna',
            onPressed: () async {
              final u = Uri.parse(_kCorseNgOfficialUrl);
              if (await canLaunchUrl(u)) {
                await launchUrl(u, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: kRomagnaDarkGray.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Informazioni',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kRomagnaPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Le corse indicate potrebbero non essere effettuate per cause '
                  'eccezionali. L’elenco è aggiornato dal giorno precedente il '
                  'servizio e può cambiare durante la giornata.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: kRomagnaDarkGray.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _bloccoData(context, oggi),
          _bloccoData(context, domani),
          TextButton.icon(
            onPressed: () async {
              final u = Uri.parse(_kCorseNgOfficialUrl);
              if (await canLaunchUrl(u)) {
                await launchUrl(u, mode: LaunchMode.externalApplication);
              }
            },
            icon: Icon(Icons.language_rounded, color: kRomagnaPrimary),
            label: Text(
              'Pagina ufficiale Start Romagna',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: kRomagnaPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
