// Abbonamenti Start Romagna — panoramica in app con link al sito ufficiale.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'abbonamenti_ordinari_sezioni.dart';
import 'biglietto_informazioni_page.dart';
import 'romagna_brand.dart';
import 'start_content/start_content_id.dart';
import 'start_content/start_content_json.dart';
import 'start_content/start_content_screen_mixin.dart';
import 'trova_biglietto_zona_page.dart';

/// Schermata «Abbonamenti»: panoramica con tariffari ordinari espandibili.
class BigliettoAbbonamentiPage extends StatefulWidget {
  const BigliettoAbbonamentiPage({super.key});

  @override
  State<BigliettoAbbonamentiPage> createState() =>
      _BigliettoAbbonamentiPageState();
}

class _BigliettoAbbonamentiPageState extends State<BigliettoAbbonamentiPage>
    with StartContentMultiMixin<BigliettoAbbonamentiPage> {
  @override
  List<StartContentId> get startContentIds => const [
    StartContentId.bigliettoAbbonamenti,
    StartContentId.abbonamentiOrdinari,
  ];

  Map<String, dynamic> get _overview =>
      contentFor(StartContentId.bigliettoAbbonamenti);

  Map<String, dynamic> get _ordinari =>
      contentFor(StartContentId.abbonamentiOrdinari);

  void _openContentUrl(Map<String, dynamic>? section, String key) {
    final url = scText(section, key);
    if (url.isEmpty) return;
    _openUrl(url);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _openInformazioni(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const BigliettoInformazioniPage(),
      ),
    );
  }

  void _openTrovaZona(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const TrovaBigliettoZonaPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Abbonamenti',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
        children: [
          const SizedBox(height: 14),
          _SectionPanel(
            children: [
              Text(
                scText(_overview, 'overviewIntro'),
                style: _bodyStyleStatic(),
              ),
              const SizedBox(height: 12),
              _ChipRow(
                chips: scStringList(_overview, 'overviewChips'),
              ),
              const SizedBox(height: 22),
              Text('Tessera Mi Muovo', style: _subtitleStyleStatic()),
              const SizedBox(height: 8),
              _BulletList(items: scStringList(_overview, 'tesseraBullets')),
              const SizedBox(height: 22),
              Text('Zone e tariffe', style: _subtitleStyleStatic()),
              const SizedBox(height: 8),
              Text(
                scText(_overview, 'zoneBody'),
                style: _bodyStyleStatic(),
              ),
              const SizedBox(height: 12),
              _ActionButton(
                label: 'Trova Zona',
                icon: Icons.search_rounded,
                filled: true,
                onTap: () => _openTrovaZona(context),
              ),
              const SizedBox(height: 8),
              _ActionButton(
                label: 'Info biglietti e tariffe',
                icon: Icons.info_outline_rounded,
                onTap: () => _openInformazioni(context),
              ),
              const SizedBox(height: 22),
              Text('Abbonamenti ordinari', style: _subtitleStyleStatic()),
              const SizedBox(height: 8),
              Text(
                scText(_overview, 'ordinariBody'),
                style: _bodyStyleStatic(),
              ),
              const SizedBox(height: 12),
              AbbonamentiOrdinariDropdown(
                title: 'Abbonamenti mensili',
                child: AbbonamentiMensiliSection(
                  content: scMap(_ordinari, 'mensili') ?? const {},
                ),
              ),
              AbbonamentiOrdinariDropdown(
                title: 'Abbonamenti annuali',
                child: AbbonamentiAnnualiSection(
                  content: scMap(_ordinari, 'annuali') ?? const {},
                ),
              ),
              ..._promoSection(scMap(_overview, 'under26')),
              ..._promoSection(
                scMap(_overview, 'saltaSu'),
                showNote: true,
              ),
              ..._promoSection(
                scMap(_overview, 'unibo'),
                showNote: true,
              ),
              ..._promoSection(scMap(_overview, 'agevolazioniMiMuovo')),
              const SizedBox(height: 22),
              Text(
                scText(_overview, 'rinnovoTitle', fallback: 'Rinnovo e ricarica'),
                style: _subtitleStyleStatic(),
              ),
              const SizedBox(height: 8),
              _BulletList(
                items: scStringList(_overview, 'rinnovoBullets'),
              ),
              const SizedBox(height: 12),
              _ActionButton(
                label: scText(
                  _overview,
                  'ricaricaButtonLabel',
                  fallback: 'Ricarica abbonamento online',
                ),
                icon: Icons.credit_card_rounded,
                filled: true,
                onTap: () => _openUrl(scText(_overview, 'ricaricaUrl')),
              ),
              const SizedBox(height: 8),
              _ActionButton(
                label: scText(
                  _overview,
                  'guidaButtonLabel',
                  fallback: 'Guida completa abbonamenti sul sito',
                ),
                icon: Icons.open_in_new_rounded,
                onTap: () => _openUrl(scText(_overview, 'guidaUrl')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _promoSection(
    Map<String, dynamic>? section, {
    bool showNote = false,
  }) {
    if (section == null || section.isEmpty) return const [];
    final title = scText(section, 'title');
    if (title.isEmpty) return const [];
    return [
      const SizedBox(height: 22),
      Text(title, style: _subtitleStyleStatic()),
      const SizedBox(height: 8),
      Text(scText(section, 'body'), style: _bodyStyleStatic()),
      if (showNote && scText(section, 'note').isNotEmpty) ...[
        const SizedBox(height: 10),
        _NoteBox(text: scText(section, 'note')),
      ],
      const SizedBox(height: 12),
      _ActionButton(
        label: scText(section, 'buttonLabel'),
        icon: Icons.open_in_new_rounded,
        onTap: () => _openContentUrl(section, 'url'),
      ),
    ];
  }
}

TextStyle _bodyStyleStatic() => GoogleFonts.inter(
  fontSize: 13.5,
  height: 1.42,
  color: kRomagnaDarkGray.withValues(alpha: 0.78),
);

TextStyle _subtitleStyleStatic() => GoogleFonts.inter(
  fontSize: 14,
  fontWeight: FontWeight.w700,
  color: kRomagnaDarkGray,
);

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
