// Acquista biglietto — contenuti da startromagna.it (Chat&Go, StarTap, app, emettitrice).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'biglietto_informazioni_page.dart';
import 'biglietto_regolamento_sanzioni_page.dart';
import 'romagna_brand.dart';
import 'servizio_clienti_page.dart';
import 'start_content/start_content_id.dart';
import 'start_content/start_content_json.dart';
import 'start_content/start_content_screen_mixin.dart';
import 'trova_biglietto_zona_page.dart';

const String _kChatGoUrl = 'https://www.startromagna.it/chat-go/';
const String _kStarTapUrl =
    'https://www.startromagna.it/biglietti/startap-sistema-emv/';
const String _kAppUrl =
    'https://www.startromagna.it/biglietti/acquista-da-smartphone/';
const String _kEmettitriceUrl =
    'https://www.startromagna.it/biglietti/acquista-da-emettitrice/';
const String _kWhatsAppChatGo = 'https://wa.me/393399951248';
const String _kVerificaQrUrl = 'https://www.startromagna.it/lettura-qr/';
const String _kMooneyGoUrl = 'https://www.mooneygo.it/';
const String _kRogerUrl = 'https://www.rogerapp.it/';
const String _kDropTicketUrl = 'https://www.dropticket.com/';
enum _AcquistaSection { whatsapp, onboard, app, emettitrice }

/// Schermata «Acquista biglietto» con sezioni espandibili e header sticky.
class BigliettoAcquistaPage extends StatefulWidget {
  const BigliettoAcquistaPage({super.key});

  @override
  State<BigliettoAcquistaPage> createState() => _BigliettoAcquistaPageState();
}

class _BigliettoAcquistaPageState extends State<BigliettoAcquistaPage>
    with StartContentScreenMixin<BigliettoAcquistaPage> {
  @override
  StartContentId get startContentId => StartContentId.bigliettoAcquista;

  List<List<String>> _fareTableRows(Map<String, dynamic> section) {
    final raw = fareRowsIn(section, 'fareTable');
    return [
      for (final row in raw)
        [row['ticket']!, row['price']!, row['validity']!],
    ];
  }
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _headerKeys = List.generate(4, (_) => GlobalKey());
  final List<GlobalKey> _bodyKeys = List.generate(4, (_) => GlobalKey());

  _AcquistaSection? _expanded;

  static const _sections = [
    (
      section: _AcquistaSection.whatsapp,
      title: 'Acquista con WhatsApp',
      icon: Icons.chat_rounded,
      color: Color(0xFF25D366),
    ),
    (
      section: _AcquistaSection.onboard,
      title: 'Acquista a bordo',
      icon: Icons.contactless_rounded,
      color: Color(0xFF2563EB),
    ),
    (
      section: _AcquistaSection.app,
      title: 'Acquista da app',
      icon: Icons.smartphone_rounded,
      color: Color(0xFF7C3AED),
    ),
    (
      section: _AcquistaSection.emettitrice,
      title: 'Acquista da emettitrice',
      icon: Icons.point_of_sale_rounded,
      color: Color(0xFFF97316),
    ),
  ];

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _openInformazioni() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const BigliettoInformazioniPage(),
      ),
    );
  }

  void _openTrovaBiglietto() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const TrovaBigliettoZonaPage()),
    );
  }

  void _openRegolamento() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const BigliettoRegolamentoSanzioniPage(),
      ),
    );
  }

  void _toggleSection(int index) {
    final section = _sections[index].section;
    final willExpand = _expanded != section;
    setState(() {
      _expanded = willExpand ? section : null;
    });
    if (willExpand) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _bodyKeys[index].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOut,
            alignment: 0,
          );
        }
      });
    }
  }

  void _expandSection(_AcquistaSection section) {
    final index = _sections.indexWhere((s) => s.section == section);
    if (index < 0) return;
    if (_expanded != section) {
      setState(() => _expanded = section);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _bodyKeys[index].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOut,
          alignment: 0,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Acquista biglietto',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Scegli come acquistare il tuo titolo di viaggio Start Romagna. '
                'Apri una sezione per i dettagli.',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  height: 1.42,
                  color: kRomagnaDarkGray.withValues(alpha: 0.72),
                ),
              ),
            ),
          ),
          for (var i = 0; i < _sections.length; i++) ...[
            SliverPersistentHeader(
              pinned: _expanded == _sections[i].section,
              delegate: _StickySectionHeaderDelegate(
                key: _headerKeys[i],
                title: _sections[i].title,
                icon: _sections[i].icon,
                accent: _sections[i].color,
                expanded: _expanded == _sections[i].section,
                onTap: () => _toggleSection(i),
              ),
            ),
            if (_expanded == _sections[i].section)
              SliverToBoxAdapter(
                child: Padding(
                  key: _bodyKeys[i],
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _sectionBody(_sections[i].section),
                ),
              ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  Widget _sectionBody(_AcquistaSection section) {
    return switch (section) {
      _AcquistaSection.whatsapp => _whatsappBody(),
      _AcquistaSection.onboard => _onboardBody(),
      _AcquistaSection.app => _appBody(),
      _AcquistaSection.emettitrice => _emettitriceBody(),
    };
  }

  Widget _whatsappBody() {
    final section = contentSection('whatsapp');
    final steps = scMapList(section, 'steps');
    return _SectionPanel(
      children: [
        Text(scText(section, 'intro'), style: _bodyStyle()),
        const SizedBox(height: 12),
        _ChipRow(chips: scStringList(section, 'chips')),
        const SizedBox(height: 14),
        Text('Come funziona', style: _subtitleStyle()),
        const SizedBox(height: 8),
        for (final step in steps)
          _NumberedStep(
            number: step['number'] as int? ?? 0,
            title: '${step['title'] ?? ''}',
            text: '${step['text'] ?? ''}',
          ),
        const SizedBox(height: 12),
        _BulletList(items: scStringList(section, 'bullets')),
        const SizedBox(height: 8),
        _NoteBox(text: scText(section, 'note')),
        const SizedBox(height: 14),
        _ActionButton(
          label: 'Avvia Chat&Go su WhatsApp',
          icon: Icons.chat_rounded,
          filled: true,
          onTap: () => _openUrl(_kWhatsAppChatGo),
        ),
        const SizedBox(height: 8),
        _ActionButton(
          label: 'Info biglietti e tariffe',
          icon: Icons.info_outline_rounded,
          onTap: _openInformazioni,
        ),
        const SizedBox(height: 8),
        _ActionButton(
          label: 'Verifica biglietto QR',
          icon: Icons.qr_code_scanner_rounded,
          onTap: () => _openUrl(_kVerificaQrUrl),
        ),
        const SizedBox(height: 8),
        _ActionButton(
          label: 'Pagina ufficiale Chat&Go',
          icon: Icons.open_in_new_rounded,
          onTap: () => _openUrl(_kChatGoUrl),
        ),
      ],
    );
  }

  Widget _onboardBody() {
    final section = contentSection('onboard');
    return _SectionPanel(
      children: [
        Text(scText(section, 'intro'), style: _bodyStyle()),
        const SizedBox(height: 12),
        Text('Prima di salire', style: _subtitleStyle()),
        const SizedBox(height: 6),
        _BulletList(items: scStringList(section, 'primaDiSalireBullets')),
        const SizedBox(height: 12),
        Text('Acquisto e conferma', style: _subtitleStyle()),
        const SizedBox(height: 6),
        _BulletList(items: scStringList(section, 'acquistoBullets')),
        const SizedBox(height: 12),
        _NoteBox(text: scText(section, 'note')),
        const SizedBox(height: 12),
        _FareTable(
          headers: const ['Titolo', 'Prezzo', 'Validità'],
          rows: _fareTableRows(section),
        ),
        const SizedBox(height: 14),
        _ActionButton(
          label: 'Info biglietti e validazione QR',
          icon: Icons.info_outline_rounded,
          onTap: _openInformazioni,
        ),
        const SizedBox(height: 8),
        _ActionButton(
          label: 'Regolamento e sanzioni',
          icon: Icons.gavel_rounded,
          onTap: _openRegolamento,
        ),
        const SizedBox(height: 8),
        _ActionButton(
          label: 'Pagina ufficiale StarTap',
          icon: Icons.open_in_new_rounded,
          onTap: () => _openUrl(_kStarTapUrl),
        ),
      ],
    );
  }

  Widget _appBody() {
    final section = contentSection('app');
    final apps = scMapList(section, 'apps');
    return _SectionPanel(
      children: [
        Text(scText(section, 'intro'), style: _bodyStyle()),
        const SizedBox(height: 12),
        for (final app in apps) ...[
          _AppCard(
            name: '${app['name'] ?? ''}',
            description: '${app['description'] ?? ''}',
            onTap: () {
              final name = '${app['name'] ?? ''}';
              if (name == 'Chat&Go') {
                _expandSection(_AcquistaSection.whatsapp);
              } else if (name == 'MooneyGo') {
                _openUrl(_kMooneyGoUrl);
              } else if (name == 'Roger') {
                _openUrl(_kRogerUrl);
              } else if (name == 'DropTicket') {
                _openUrl(_kDropTicketUrl);
              }
            },
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        _NoteBox(text: scText(section, 'note')),
        const SizedBox(height: 12),
        _ActionButton(
          label: 'Trova biglietto',
          icon: Icons.search_rounded,
          filled: true,
          onTap: _openTrovaBiglietto,
        ),
        const SizedBox(height: 8),
        _ActionButton(
          label: 'Info biglietti e tariffe',
          icon: Icons.info_outline_rounded,
          onTap: _openInformazioni,
        ),
        const SizedBox(height: 8),
        _ActionButton(
          label: 'Pagina ufficiale acquisto da smartphone',
          icon: Icons.open_in_new_rounded,
          onTap: () => _openUrl(_kAppUrl),
        ),
      ],
    );
  }

  Widget _emettitriceBody() {
    final section = contentSection('emettitrice');
    return _SectionPanel(
      children: [
        Text(scText(section, 'intro'), style: _bodyStyle()),
        const SizedBox(height: 12),
        Text('Emettitrici di terra AEP', style: _subtitleStyle()),
        const SizedBox(height: 6),
        _BulletList(items: scStringList(section, 'terraBullets')),
        const SizedBox(height: 12),
        Text('Emettitrici traghetto', style: _subtitleStyle()),
        const SizedBox(height: 6),
        Text(scText(section, 'traghettoBody'), style: _bodyStyle()),
        const SizedBox(height: 12),
        Text('Emettitrici di bordo (Rimini)', style: _subtitleStyle()),
        const SizedBox(height: 6),
        _BulletList(items: scStringList(section, 'bordoBullets')),
        const SizedBox(height: 12),
        Text('Tariffe a bordo (sovrapprezzo)', style: _subtitleStyle()),
        const SizedBox(height: 6),
        _FareTable(
          headers: const ['Biglietto', 'Prezzo', 'Validità'],
          rows: _fareTableRows(section),
        ),
        const SizedBox(height: 14),
        _ActionButton(
          label: 'Info biglietti e tariffe',
          icon: Icons.info_outline_rounded,
          filled: true,
          onTap: _openInformazioni,
        ),
        const SizedBox(height: 8),
        _ActionButton(
          label: 'Regolamento e sanzioni',
          icon: Icons.gavel_rounded,
          onTap: _openRegolamento,
        ),
        const SizedBox(height: 8),
        _ActionButton(
          label: 'Pagina ufficiale emettitrici',
          icon: Icons.open_in_new_rounded,
          onTap: () => _openUrl(_kEmettitriceUrl),
        ),
        const SizedBox(height: 8),
        _ActionButton(
          label: 'Contatti',
          icon: Icons.call_outlined,
          onTap: () => openContattiPage(context),
        ),
      ],
    );
  }

  TextStyle _bodyStyle() => GoogleFonts.inter(
    fontSize: 13.5,
    height: 1.42,
    color: kRomagnaDarkGray.withValues(alpha: 0.78),
  );

  TextStyle _subtitleStyle() => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: kRomagnaDarkGray,
  );
}

class _StickySectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StickySectionHeaderDelegate({
    required this.title,
    required this.icon,
    required this.accent,
    required this.expanded,
    required this.onTap,
    GlobalKey? key,
  }) : _key = key;

  final String title;
  final IconData icon;
  final Color accent;
  final bool expanded;
  final VoidCallback onTap;
  final GlobalKey? _key;

  static const double _height = 58;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return KeyedSubtree(
      key: _key,
      child: Material(
        color: Colors.white,
        elevation: overlapsContent || shrinkOffset > 0 ? 2 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: _height,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: kRomagnaDarkGray.withValues(alpha: 0.08),
                ),
                left: BorderSide(color: accent, width: expanded ? 4 : 0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 19, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kRomagnaDarkGray,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: kRomagnaDarkGray.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickySectionHeaderDelegate oldDelegate) {
    return oldDelegate.expanded != expanded ||
        oldDelegate.title != title ||
        oldDelegate.accent != accent;
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kRomagnaDarkGray.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
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

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({
    required this.number,
    required this.title,
    required this.text,
  });

  final int number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: kRomagnaDarkGray,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: GoogleFonts.inter(
                fontSize: 13,
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
                const SizedBox(height: 2),
                Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.4,
                    color: kRomagnaDarkGray.withValues(alpha: 0.72),
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

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.chips});

  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in chips)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: kRomagnaPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: kRomagnaPrimary.withValues(alpha: 0.22),
              ),
            ),
            child: Text(
              c,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kRomagnaPrimary,
              ),
            ),
          ),
      ],
    );
  }
}

class _FareTable extends StatelessWidget {
  const _FareTable({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;

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
                for (var i = 0; i < headers.length; i++)
                  Expanded(
                    flex: i == 0 ? 4 : 3,
                    child: Text(
                      headers[i],
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
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0)
              Divider(
                height: 1,
                color: kRomagnaDarkGray.withValues(alpha: 0.06),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  for (var c = 0; c < rows[r].length; c++)
                    Expanded(
                      flex: c == 0 ? 4 : 3,
                      child: Text(
                        rows[r][c],
                        style: GoogleFonts.inter(
                          fontSize: c == 1 ? 13 : 12.5,
                          fontWeight:
                              c == 1 ? FontWeight.w700 : FontWeight.w500,
                          color: kRomagnaDarkGray.withValues(
                            alpha: c == 0 ? 1 : 0.72,
                          ),
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(
            label,
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
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: kRomagnaPrimary,
          side: BorderSide(color: kRomagnaPrimary.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  const _AppCard({
    required this.name,
    required this.description,
    required this.onTap,
  });

  final String name;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kRomagnaDarkGray.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kRomagnaPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.38,
                  color: kRomagnaDarkGray.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
