// Info biglietti e tariffe — contenuto da startromagna.it/ticket-qr-code/

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'romagna_brand.dart';
import 'start_content/start_content_id.dart';
import 'start_content/start_content_screen_mixin.dart';
import 'trova_biglietto_zona_page.dart';
import 'verifica_biglietto_qr_page.dart';

const String _kTicketInfoSourceUrl =
    'https://www.startromagna.it/ticket-qr-code/';

class _FareRow {
  const _FareRow(this.ticket, this.price, this.validity);

  final String ticket;
  final String price;
  final String validity;
}

class _ZoneLegendItem {
  const _ZoneLegendItem(this.label, this.color);

  final String label;
  final Color color;
}

/// Schermata «Informazioni generali» nel menù Biglietto.
class BigliettoInformazioniPage extends StatefulWidget {
  const BigliettoInformazioniPage({super.key});

  @override
  State<BigliettoInformazioniPage> createState() =>
      _BigliettoInformazioniPageState();
}

class _BigliettoInformazioniPageState extends State<BigliettoInformazioniPage>
    with StartContentScreenMixin<BigliettoInformazioniPage> {
  @override
  StartContentId get startContentId => StartContentId.bigliettoInformazioni;

  List<_FareRow> _fareRowsFrom(String key) => [
    for (final r in fareRows(key))
      _FareRow(r['ticket'] ?? '', r['price'] ?? '', r['validity'] ?? ''),
  ];

  List<Widget> _multicorsaStepWidgets() {
    final raw = content['multicorsaSteps'];
    if (raw is! List || raw.isEmpty) return const [];
    final out = <Widget>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final bullets = item['bullets'];
      out.add(
        _NumberedStep(
          number: item['number'] is int
              ? item['number'] as int
              : int.tryParse('${item['number']}') ?? out.length + 1,
          title: '${item['title']}',
          bullets:
              bullets is List
                  ? [for (final b in bullets) '$b']
                  : const <String>[],
        ),
      );
      out.add(const SizedBox(height: 10));
    }
    if (out.isNotEmpty) out.removeLast();
    return out;
  }

  List<Widget> _faqWidgets() {
    final raw = content['faq'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          _FaqItem(
            question: '${item['question']}',
            answer: '${item['answer']}',
          ),
    ];
  }

  static const _zoneLegend = [
    _ZoneLegendItem('1 zona', Color(0xFFFACC15)),
    _ZoneLegendItem('2 zone', Color(0xFF86EFAC)),
    _ZoneLegendItem('3 zone', Color(0xFF2563EB)),
    _ZoneLegendItem('4 zone', Color(0xFFEC4899)),
    _ZoneLegendItem('5 zone', Color(0xFF7C3AED)),
    _ZoneLegendItem('6 zone', Color(0xFF38BDF8)),
    _ZoneLegendItem('7 zone', Color(0xFFF97316)),
    _ZoneLegendItem('8 zone', Color(0xFFEF4444)),
    _ZoneLegendItem('9 zone', Color(0xFF166534)),
  ];

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Informazioni generali',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: contentLoading && content.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _IntroHero(
            onTrovaZona:
                () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const TrovaBigliettoZonaPage(),
                  ),
                ),
          ),
          const SizedBox(height: 14),
          _InfoSectionCard(
            icon: Icons.map_outlined,
            kicker: 'Informazioni',
            title: 'Le zone tariffarie',
            children: [
              if (stringList('zoneIntro').isNotEmpty)
                for (final p in stringList('zoneIntro')) ...[
                  Text(p, style: _bodyStyle()),
                  const SizedBox(height: 8),
                ]
              else ...[
                Text(
                  'Il territorio regionale è suddiviso in zone: la tariffa dipende '
                  'dal numero di zone attraversate tra partenza e destinazione.',
                  style: _bodyStyle(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Le paline di fermata indicano la zona; puoi verificarla anche '
                  'nella card fermata sulla mappa.',
                  style: _bodyStyle(),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Un colore per ogni zona',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kRomagnaDarkGray,
                ),
              ),
              const SizedBox(height: 10),
              _ZoneLegendGrid(items: _zoneLegend),
            ],
          ),
          _InfoSectionCard(
            icon: Icons.confirmation_number_outlined,
            kicker: 'Biglietti',
            title: 'Corsa semplice',
            children: [
              Text(
                contentString(
                  'corsaSempliceIntro',
                  fallback:
                      'Consentono di viaggiare anche con più mezzi nell’ambito del '
                      'numero di zone riportato sul titolo. Devono essere convalidati '
                      'appena saliti sul bus nell’apposito validatore.',
                ),
                style: _bodyStyle(),
              ),
              const SizedBox(height: 12),
              const _InfoImage(assetPath: 'assets/biglietti/ticket.jpg'),
              const SizedBox(height: 12),
              const _InfoImage(assetPath: 'assets/biglietti/1-zona.jpg'),
              const SizedBox(height: 12),
              _FareTable(rows: _fareRowsFrom('corsaSemplice')),
            ],
          ),
          _InfoSectionCard(
            icon: Icons.layers_outlined,
            kicker: 'Multicorsa',
            title: 'Multicorsa (10 ticket)',
            children: [
              Text(
                contentString('multicorsaIntro'),
                style: _bodyStyle(),
              ),
              const SizedBox(height: 12),
              _FareTable(rows: _fareRowsFrom('multicorsa')),
              const SizedBox(height: 16),
              Text(
                'Come si valida con QR Code',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kRomagnaDarkGray,
                ),
              ),
              const SizedBox(height: 10),
              ..._multicorsaStepWidgets(),
            ],
          ),
          _InfoSectionCard(
            icon: Icons.today_outlined,
            kicker: 'Giornalieri',
            title: 'Day Ticket',
            children: [
              for (final p in stringList('dayTicketIntro')) ...[
                Text(p, style: _bodyStyle()),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 4),
              _FareTable(rows: _fareRowsFrom('dayTicket')),
              const SizedBox(height: 10),
              _NoteBox(text: contentString('dayTicketNote')),
            ],
          ),
          _InfoSectionCard(
            icon: Icons.directions_bus_filled_outlined,
            kicker: 'Metromare',
            title: 'Biglietto Metromare',
            accent: kMetromareRed,
            children: [
              Text(contentString('metromareIntro'), style: _bodyStyle()),
              const SizedBox(height: 12),
              const _InfoImage(assetPath: 'assets/biglietti/metromare.jpg'),
              const SizedBox(height: 12),
              _FareTable(rows: _fareRowsFrom('metromare')),
              const SizedBox(height: 10),
              Text(contentString('metromarePurchase'), style: _bodyStyle()),
            ],
          ),
          _InfoSectionCard(
            icon: Icons.payments_outlined,
            kicker: 'A bordo',
            title: 'Biglietti venduti a bordo',
            children: [
              Text(contentString('aBordoIntro'), style: _bodyStyle()),
              const SizedBox(height: 12),
              _FareTable(rows: _fareRowsFrom('aBordo')),
            ],
          ),
          _InfoSectionCard(
            icon: Icons.card_travel_outlined,
            kicker: 'Pass',
            title: 'Titoli turistici',
            children: [
              _PassHighlight(
                title: content['smartPass'] is Map
                    ? '${(content['smartPass'] as Map)['title']}'
                    : 'Romagna SmartPass',
                description: content['smartPass'] is Map
                    ? '${(content['smartPass'] as Map)['description']}'
                    : '',
              ),
              const SizedBox(height: 10),
              _PassHighlight(
                title: content['railSmartPass'] is Map
                    ? '${(content['railSmartPass'] as Map)['title']}'
                    : 'Rail SmartPass',
                description: content['railSmartPass'] is Map
                    ? '${(content['railSmartPass'] as Map)['description']}'
                    : '',
              ),
            ],
          ),
          _InfoSectionCard(
            icon: Icons.qr_code_2_rounded,
            kicker: 'QR Code',
            title: 'Validazione e verifica',
            children: [
              const _InfoImage(assetPath: 'assets/biglietti/qr_poster.jpg'),
              const SizedBox(height: 12),
              const _InfoImage(assetPath: 'assets/biglietti/validatrice.png'),
              const SizedBox(height: 12),
              Text(contentString('qrValidation'), style: _bodyStyle()),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const VerificaBigliettoQrPage(),
                        ),
                      ),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: Text(
                    'Apri scanner QR',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
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
          _InfoSectionCard(
            icon: Icons.help_outline_rounded,
            kicker: 'FAQ',
            title: 'Domande frequenti',
            children: _faqWidgets(),
          ),
          const SizedBox(height: 8),
          Text(
            contentString(
              'footerNote',
              fallback:
                  'Dati ufficiali dal sito startromagna.it. Per il titolo adatto '
                  'al tuo viaggio puoi usare anche «Trova biglietto» in app.',
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              height: 1.4,
              color: kRomagnaDarkGray.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () => _openUrl(_kTicketInfoSourceUrl),
              child: Text(
                'Apri pagina ufficiale',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kRomagnaPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _bodyStyle() => GoogleFonts.inter(
    fontSize: 13.5,
    height: 1.42,
    color: kRomagnaDarkGray.withValues(alpha: 0.78),
  );
}

class _IntroHero extends StatelessWidget {
  const _IntroHero({required this.onTrovaZona});

  final VoidCallback onTrovaZona;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [kRomagnaPrimary, kRomagnaPrimary.withValues(alpha: 0.82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: kRomagnaPrimary.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Info biglietti e tariffe',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Zone tariffarie, principali titoli di viaggio, prezzi e '
            'indicazioni per la validazione con QR Code.',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onTrovaZona,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: kRomagnaDarkGray,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    'Calcola le zone',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoSectionCard extends StatelessWidget {
  const _InfoSectionCard({
    required this.icon,
    required this.kicker,
    required this.title,
    required this.children,
    this.accent,
  });

  final IconData icon;
  final String kicker;
  final String title;
  final List<Widget> children;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? kRomagnaPrimary;
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
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kicker.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.06,
                        color: color,
                      ),
                    ),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kRomagnaDarkGray,
                        height: 1.2,
                      ),
                    ),
                  ],
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

class _ZoneLegendGrid extends StatelessWidget {
  const _ZoneLegendGrid({required this.items});

  final List<_ZoneLegendItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final z in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8FC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: kRomagnaDarkGray.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: z.color,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  z.label,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: kRomagnaDarkGray.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FareTable extends StatelessWidget {
  const _FareTable({required this.rows});

  final List<_FareRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kRomagnaDarkGray.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: kRomagnaPrimary.withValues(alpha: 0.08),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'Biglietto',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: kRomagnaDarkGray.withValues(alpha: 0.65),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Prezzo',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: kRomagnaDarkGray.withValues(alpha: 0.65),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Validità',
                    textAlign: TextAlign.end,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: kRomagnaDarkGray.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: kRomagnaDarkGray.withValues(alpha: 0.06),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      rows[i].ticket,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.3,
                        color: kRomagnaDarkGray,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      rows[i].price,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kRomagnaDarkGray,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      rows[i].validity,
                      textAlign: TextAlign.end,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: kRomagnaDarkGray.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoImage extends StatelessWidget {
  const _InfoImage({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: const Color(0xFFF5F8FC),
        padding: const EdgeInsets.all(8),
        child: Image.asset(assetPath, fit: BoxFit.contain),
      ),
    );
  }
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({
    required this.number,
    required this.title,
    required this.bullets,
  });

  final int number;
  final String title;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: kRomagnaDarkGray,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: kRomagnaDarkGray,
                ),
              ),
              const SizedBox(height: 6),
              for (final b in bullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: kRomagnaPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          b,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.4,
                            color: kRomagnaDarkGray.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12.5,
          height: 1.4,
          color: const Color(0xFF9A3412),
        ),
      ),
    );
  }
}

class _PassHighlight extends StatelessWidget {
  const _PassHighlight({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kRomagnaDarkGray.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kRomagnaDarkGray,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: kRomagnaDarkGray.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: kRomagnaDarkGray,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: kRomagnaDarkGray.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}
