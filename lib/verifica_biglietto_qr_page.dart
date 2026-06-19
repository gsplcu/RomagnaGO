// Verifica biglietto QR - seriale in app + scanner fotocamera sul sito Start Romagna.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';

import 'romagna_brand.dart';

const String _kQrCheckInfoUrl = 'https://www.startromagna.it/lettura-qr/';
const String _kQrScannerWebUrl =
    'https://servizi.startromagna.it/LetturaQr/HomePage.aspx';
const String _kSerialPrefix = '3-';
const int _kSerialDigitsLength = 8;

class VerificaBigliettoQrPage extends StatefulWidget {
  const VerificaBigliettoQrPage({super.key});

  @override
  State<VerificaBigliettoQrPage> createState() =>
      _VerificaBigliettoQrPageState();
}

class _VerificaBigliettoQrPageState extends State<VerificaBigliettoQrPage> {
  final TextEditingController _serialController = TextEditingController();

  @override
  void dispose() {
    _serialController.dispose();
    super.dispose();
  }

  Uri _buildResultUri({required String value, required bool isSerial}) {
    return Uri.https(
      'servizi.startromagna.it',
      '/LetturaQr/VisualizzaQr.aspx',
      isSerial ? {'serialQr': value} : {'qrData': value},
    );
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _openResult({
    required String value,
    required bool isSerial,
  }) async {
    final uri = _buildResultUri(value: value, isSerial: isSerial);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _QrCheckResultPage(initialUrl: uri.toString()),
      ),
    );
  }

  Future<void> _verifyManualSerial() async {
    final digits = _serialController.text.trim();
    if (digits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci le 8 cifre del seriale dopo il prefisso.'),
        ),
      );
      return;
    }
    if (digits.length != _kSerialDigitsLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Il seriale deve avere $_kSerialDigitsLength cifre (es. $_kSerialPrefix${'0' * _kSerialDigitsLength}).',
          ),
        ),
      );
      return;
    }
    await _openResult(value: '$_kSerialPrefix$digits', isSerial: true);
  }

  Future<void> _openScannerOnSite() async {
    await _openExternal(_kQrScannerWebUrl);
  }

  void _showSerialLocationDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Dove si trova il seriale',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kRomagnaDarkGray,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('assets/1-zona.jpg', fit: BoxFit.contain),
                ),
                const SizedBox(height: 12),
                Text(
                  'Il seriale si trova sul biglietto sotto al codice QR, '
                  'come nell\'esempio.',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    height: 1.42,
                    color: kRomagnaDarkGray.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Chiudi',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: kRomagnaPrimary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Verifica il tuo biglietto QR code',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Apri pagina ufficiale',
            onPressed: () => _openExternal(_kQrCheckInfoUrl),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    kRomagnaPrimary,
                    kRomagnaPrimary.withValues(alpha: 0.82),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scansiona o inserisci il seriale',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scansiona il QR sul sito Start Romagna oppure inserisci '
                    'manualmente il seriale per verificare la validità.',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      height: 1.42,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Scanner QR sul sito',
              icon: Icons.qr_code_scanner_rounded,
              accent: kRomagnaPrimary,
              children: [
                Text(
                  'La scansione con fotocamera è disponibile sul sito ufficiale Start '
                  'Romagna: inquadra il QR del biglietto e scatta una foto per '
                  'vedere l’esito della verifica.',
                  style: _bodyStyle(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openScannerOnSite,
                    icon: const Icon(Icons.open_in_browser_rounded),
                    label: Text(
                      'Scatta foto sul sito',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: kRomagnaPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            _SectionCard(
              title: 'Verifica manuale',
              icon: Icons.keyboard_outlined,
              accent: const Color(0xFF7C3AED),
              children: [
                Text(
                  'In alternativa, inserisci le 8 cifre del seriale (il prefisso 3- è '
                  'già impostato) e avvia la verifica direttamente dall’app.',
                  style: _bodyStyle(),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _showSerialLocationDialog,
                  child: Text(
                    'Dove si trova il seriale',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kRomagnaPrimary,
                      decoration: TextDecoration.underline,
                      decorationColor: kRomagnaPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: _serialController,
                  builder: (context, _) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: _SerialDigitsField(
                        controller: _serialController,
                        onSubmitted: _verifyManualSerial,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _verifyManualSerial,
                    icon: const Icon(Icons.search_rounded),
                    label: Text(
                      'Verifica seriale',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: kRomagnaPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _openExternal(_kQrCheckInfoUrl),
                  child: Text(
                    'Apri la pagina ufficiale',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: kRomagnaPrimary,
                    ),
                  ),
                ),
              ],
            ),
            _SectionCard(
              title: 'Come funziona',
              icon: Icons.info_outline_rounded,
              accent: const Color(0xFF0EA5E9),
              children: const [
                _BulletList(
                  items: [
                    'Per la scansione con fotocamera usa il sito Start Romagna; qui puoi verificare il seriale in app.',
                    'Dopo la lettura, il servizio restituisce la validità del titolo prima della partenza.',
                    'I biglietti vanno comunque validati a bordo sul lettore verde F3B.',
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _bodyStyle() => GoogleFonts.inter(
    fontSize: 13.5,
    height: 1.42,
    color: kRomagnaDarkGray.withValues(alpha: 0.78),
  );
}

class _SerialDigitsField extends StatelessWidget {
  const _SerialDigitsField({
    required this.controller,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;

  static final _underlineColor = kRomagnaDarkGray.withValues(alpha: 0.28);

  @override
  Widget build(BuildContext context) {
    final prefixStyle = GoogleFonts.inter(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      color: kRomagnaDarkGray,
      letterSpacing: 0.5,
    );

    final underline = UnderlineInputBorder(
      borderSide: BorderSide(color: _underlineColor),
    );
    final focusedUnderline = UnderlineInputBorder(
      borderSide: BorderSide(color: kRomagnaPrimary, width: 2),
    );

    final hasDigits = controller.text.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 10, bottom: 12),
          child: Text(_kSerialPrefix, style: prefixStyle),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: _kSerialDigitsLength,
            textAlign: TextAlign.left,
            onSubmitted: (_) => onSubmitted(),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_kSerialDigitsLength),
              const _SerialDigitsInputFormatter(),
            ],
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: kRomagnaDarkGray,
            ),
            decoration: InputDecoration(
              hintText: '00001234',
              counterText: '',
              isDense: true,
              contentPadding: const EdgeInsets.fromLTRB(0, 12, 4, 12),
              border: underline,
              enabledBorder: underline,
              focusedBorder: focusedUnderline,
            ),
          ),
        ),
        if (hasDigits)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: IconButton(
              tooltip: 'Cancella cifre',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: kRomagnaDarkGray.withValues(alpha: 0.55),
              ),
              onPressed: controller.clear,
            ),
          ),
      ],
    );
  }
}

class _SerialDigitsInputFormatter extends TextInputFormatter {
  const _SerialDigitsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('3') && digits.length > _kSerialDigitsLength) {
      digits = digits.substring(1);
    }
    if (digits.length > _kSerialDigitsLength) {
      digits = digits.substring(0, _kSerialDigitsLength);
    }
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

class _QrCheckResultPage extends StatefulWidget {
  const _QrCheckResultPage({required this.initialUrl});

  final String initialUrl;

  @override
  State<_QrCheckResultPage> createState() => _QrCheckResultPageState();
}

class _QrCheckResultPageState extends State<_QrCheckResultPage> {
  late final Future<_QrCheckResultData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_QrCheckResultData> _load() async {
    final res = await http.get(
      Uri.parse(widget.initialUrl),
      headers: const {'Accept': 'text/html,application/xhtml+xml'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return _parseQrCheckHtml(res.body);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Esito verifica',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: FutureBuilder<_QrCheckResultData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: _SectionCard(
                title: 'Errore di caricamento',
                icon: Icons.error_outline_rounded,
                accent: Colors.redAccent,
                children: [
                  Text(
                    'Non riesco a caricare l’esito ufficiale.',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: kRomagnaDarkGray,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    snapshot.error.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      height: 1.4,
                      color: kRomagnaDarkGray.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          if (data.isError) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                Text(
                  data.pageTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.oswald(
                    fontSize: 34,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF336699),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  data.errorMessage ?? 'Seriale non valido',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.oswald(
                    fontSize: 28,
                    color: const Color(0xFF336699),
                  ),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
            children: [
              Text(
                data.pageTitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.oswald(
                  fontSize: 36,
                  fontWeight: FontWeight.w400,
                  color: kRomagnaDarkGray,
                ),
              ),
              const SizedBox(height: 20),
              _TicketInfoTable(rows: data.rows),
            ],
          );
        },
      ),
    );
  }
}

_QrCheckResultData _parseQrCheckHtml(String html) {
  final doc = html_parser.parse(html);

  final invalidMsg = doc.querySelector('.Literal1')?.text.trim();
  if (invalidMsg != null && invalidMsg.isNotEmpty) {
    return _QrCheckResultData.error(
      pageTitle: doc.querySelector('h1')?.text.trim() ?? 'Info Titolo',
      message: invalidMsg,
    );
  }

  final pageTitle = doc.querySelector('h1')?.text.trim() ?? 'Info Titolo';
  final rows = <_QrTicketRow>[];

  for (final tr in doc.querySelectorAll('tr.table_info')) {
    final cells =
        tr.children
            .whereType<dom.Element>()
            .where((dom.Element e) => e.localName == 'td')
            .toList();
    if (cells.length < 2) continue;

    final label = _cellText(cells[0]);
    if (label.isEmpty) continue;

    final values = _extractValues(cells[1]);
    rows.add(_QrTicketRow(label: label, values: values));
  }

  return _QrCheckResultData.success(pageTitle: pageTitle, rows: rows);
}

String _cellText(dom.Element element) {
  return element.text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<String> _extractValues(dom.Element valueCell) {
  final spans = valueCell.querySelectorAll('span');
  final values = <String>[];
  for (final span in spans) {
    final text = span.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isNotEmpty) values.add(text);
  }

  if (values.isNotEmpty) return values;

  final text = _cellText(valueCell);
  return text.isEmpty ? const [] : [text];
}

class _QrCheckResultData {
  const _QrCheckResultData._({
    required this.pageTitle,
    required this.rows,
    required this.isError,
    this.errorMessage,
  });

  factory _QrCheckResultData.success({
    required String pageTitle,
    required List<_QrTicketRow> rows,
  }) => _QrCheckResultData._(pageTitle: pageTitle, rows: rows, isError: false);

  factory _QrCheckResultData.error({
    required String pageTitle,
    required String message,
  }) => _QrCheckResultData._(
    pageTitle: pageTitle,
    rows: const [],
    isError: true,
    errorMessage: message,
  );

  final String pageTitle;
  final List<_QrTicketRow> rows;
  final bool isError;
  final String? errorMessage;
}

class _QrTicketRow {
  const _QrTicketRow({required this.label, required this.values});

  final String label;
  final List<String> values;
}

class _TicketInfoTable extends StatelessWidget {
  const _TicketInfoTable({required this.rows});

  final List<_QrTicketRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCCCCCC)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: Color(0xFFDDDDDD)),
            _TicketInfoTableRow(row: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _TicketInfoTableRow extends StatelessWidget {
  const _TicketInfoTableRow({required this.row});

  final _QrTicketRow row;

  @override
  Widget build(BuildContext context) {
    final labelStyle = GoogleFonts.nunito(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      color: const Color(0xFF336699),
      height: 1.25,
    );
    final valueStyle = GoogleFonts.nunito(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: kRomagnaDarkGray,
      height: 1.35,
    );

    return Container(
      color: const Color(0xFFF8F8F8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 11,
            child: Text(
              row.label,
              textAlign: TextAlign.center,
              style: labelStyle,
            ),
          ),
          Expanded(
            flex: 10,
            child:
                row.values.isEmpty
                    ? Text('', textAlign: TextAlign.center, style: valueStyle)
                    : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final value in row.values)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              value,
                              textAlign: TextAlign.center,
                              style: valueStyle,
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kRomagnaDarkGray.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kRomagnaDarkGray,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: kRomagnaPrimary,
                    height: 1.4,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.42,
                      color: kRomagnaDarkGray.withValues(alpha: 0.74),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
