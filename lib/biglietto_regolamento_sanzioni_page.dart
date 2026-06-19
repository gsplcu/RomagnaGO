// Regolamento e sanzioni - contenuti da startromagna.it/biglietti/regolamenti-sanzioni-regole-di-viaggio/

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'biglietto_informazioni_page.dart';
import 'romagna_brand.dart';
import 'servizio_clienti_page.dart';
import 'start_content/start_content_id.dart';
import 'start_content/start_content_json.dart';
import 'start_content/start_content_screen_mixin.dart';
import 'trova_biglietto_zona_page.dart';

const String _kRegolamentoViaggioPdfFallback =
    'https://www.startromagna.it/wp-content/uploads/2025/05/Regolamento-di-viaggio-Start-Romagna_5.5.25.pdf';

class BigliettoRegolamentoSanzioniPage extends StatefulWidget {
  const BigliettoRegolamentoSanzioniPage({super.key});

  @override
  State<BigliettoRegolamentoSanzioniPage> createState() =>
      _BigliettoRegolamentoSanzioniPageState();
}

class _BigliettoRegolamentoSanzioniPageState
    extends State<BigliettoRegolamentoSanzioniPage>
    with StartContentScreenMixin<BigliettoRegolamentoSanzioniPage> {
  @override
  StartContentId get startContentId => StartContentId.bigliettoRegolamento;

  String _pdf(String key, {String fallback = ''}) {
    final urls = scMap(content, 'pdfUrls');
    return scText(urls, key, fallback: fallback);
  }
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _ticketsKey = GlobalKey();
  final GlobalKey _qrKey = GlobalKey();
  final GlobalKey _ticketRulesKey = GlobalKey();
  final GlobalKey _regulationKey = GlobalKey();
  final GlobalKey _strikeKey = GlobalKey();
  final GlobalKey _complaintsKey = GlobalKey();
  final GlobalKey _sanctionsKey = GlobalKey();

  void _openContatti() => openContattiPage(context);

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
          'Regolamento e sanzioni',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const _HeroCard(),
          const SizedBox(height: 14),
          _SectionCard(
            key: _ticketsKey,
            icon: Icons.confirmation_number_outlined,
            kicker: 'Titoli di viaggio',
            title: 'Acquisto e convalida',
            accent: const Color(0xFF2563EB),
            children: [
              Text(scText(content, 'titoliIntro'), style: _bodyStyle()),
              const SizedBox(height: 10),
              _BulletList(items: scStringList(content, 'titoliBullets')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const BigliettoInformazioniPage(),
                            ),
                          ),
                      style: FilledButton.styleFrom(
                        backgroundColor: kRomagnaPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Apri info biglietti',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const TrovaBigliettoZonaPage(),
                            ),
                          ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kRomagnaPrimary,
                        side: BorderSide(
                          color: kRomagnaPrimary.withValues(alpha: 0.35),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Trova biglietto',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          _SectionCard(
            key: _qrKey,
            icon: Icons.qr_code_2_rounded,
            kicker: 'QR Code',
            title: 'Nuovi titoli e validazione',
            accent: const Color(0xFF111827),
            children: [
              Text(scText(content, 'qrIntro'), style: _bodyStyle()),
              const SizedBox(height: 12),
              _ImageCard(
                assetPath: 'assets/biglietti/regolamento-qr.jpg',
                caption: 'Esempio di biglietto QR e validazione',
              ),
              const SizedBox(height: 12),
              _BulletList(items: scStringList(content, 'qrBullets')),
            ],
          ),
          _SectionCard(
            key: _ticketRulesKey,
            icon: Icons.rule_outlined,
            kicker: 'Bigliettazione',
            title: 'Regole generali relative alla bigliettazione',
            accent: const Color(0xFF0EA5E9),
            children: [
              _BulletList(items: scStringList(content, 'bigliettazioneBullets')),
            ],
          ),
          _SectionCard(
            key: _regulationKey,
            icon: Icons.description_outlined,
            kicker: 'Regolamento',
            title: 'Regolamento di viaggio',
            accent: const Color(0xFF7C3AED),
            children: [
              Text(scText(content, 'regolamentoIntro'), style: _bodyStyle()),
              const SizedBox(height: 12),
              _DocumentButton(
                title: 'Regolamento di viaggio',
                subtitle: 'Documento integrale PDF',
                icon: Icons.picture_as_pdf_outlined,
                color: const Color(0xFF7C3AED),
                onTapUrl: _pdf(
                  'regolamentoViaggio',
                  fallback: _kRegolamentoViaggioPdfFallback,
                ),
              ),
              const SizedBox(height: 10),
              _DocumentButton(
                title: 'Sintesi norme di viaggio',
                subtitle: 'Sintesi da tenere a bordo',
                icon: Icons.summarize_outlined,
                color: const Color(0xFF7C3AED),
                onTapUrl: _pdf('sintesiRegolamento'),
              ),
              const SizedBox(height: 10),
              _DocumentButton(
                title: 'Regolamento bici e monopattino pieghevoli',
                subtitle: 'Regole dedicate al trasporto',
                icon: Icons.pedal_bike_outlined,
                color: const Color(0xFF7C3AED),
                onTapUrl: _pdf('biciMonopattino'),
              ),
            ],
          ),
          _SectionCard(
            key: _strikeKey,
            icon: Icons.campaign_outlined,
            kicker: 'Sciopero',
            title: 'Diritto di sciopero e servizi garantiti',
            accent: const Color(0xFFF97316),
            children: [
              for (var i = 0; i < scMapList(content, 'sciopero').length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _StrikeAreaCard(
                  title: '${scMapList(content, 'sciopero')[i]['title'] ?? ''}',
                  lines: scStringList(
                    scMapList(content, 'sciopero')[i],
                    'lines',
                  ),
                ),
              ],
            ],
          ),
          _SectionCard(
            key: _complaintsKey,
            icon: Icons.forum_outlined,
            kicker: 'Reclami',
            title: 'Reclami e segnalazioni',
            accent: const Color(0xFF0F766E),
            children: [
              Text(scText(content, 'reclamiIntro'), style: _bodyStyle()),
              const SizedBox(height: 12),
              _DocumentButton(
                title: 'Modulo reclamo ART',
                subtitle: 'PDF per il reclamo di seconda istanza',
                icon: Icons.picture_as_pdf_outlined,
                color: const Color(0xFF0F766E),
                onTapUrl: _pdf('moduloReclamo'),
              ),
              const SizedBox(height: 10),
              _DocumentButton(
                title: 'Servizio clienti',
                subtitle: 'Apri Contatti in app',
                icon: Icons.support_agent_outlined,
                color: const Color(0xFF0F766E),
                onTap: _openContatti,
                trailingIcon: Icons.chevron_right_rounded,
              ),
            ],
          ),
          _SectionCard(
            key: _sanctionsKey,
            icon: Icons.gavel_rounded,
            kicker: 'Sanzioni',
            title: 'Sanzioni amministrative',
            accent: const Color(0xFFEF4444),
            children: [
              Text(scText(content, 'sanzioniIntro'), style: _bodyStyle()),
              const SizedBox(height: 12),
              _DocumentButton(
                title: 'Sanzioni amministrative',
                subtitle: 'Documento aggiornato',
                icon: Icons.picture_as_pdf_outlined,
                color: const Color(0xFFEF4444),
                onTapUrl: _pdf('sanzioni'),
              ),
              const SizedBox(height: 10),
              _DocumentButton(
                title: 'Normativa sanzioni amministrative',
                subtitle: 'Riferimenti e regole applicate',
                icon: Icons.article_outlined,
                color: const Color(0xFFEF4444),
                onTapUrl: _pdf('sanzioniRules'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: kRomagnaDarkGray.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Serve aiuto?',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kRomagnaDarkGray,
                  ),
                ),
                const SizedBox(height: 6),
                Text(scText(content, 'helpIntro'), style: _bodyStyle()),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openContatti,
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: Text(
                      'Vai a Contatti',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kRomagnaPrimary,
                      side: BorderSide(
                        color: kRomagnaPrimary.withValues(alpha: 0.35),
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

class _HeroCard extends StatelessWidget {
  const _HeroCard();

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
            color: kRomagnaPrimary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Diritti e doveri dei passeggeri',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Documenti, regole di utilizzo e sanzioni amministrative per viaggiare con Start Romagna.',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
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

class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.assetPath, required this.caption});

  final String assetPath;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: const Color(0xFFF5F8FC),
            padding: const EdgeInsets.all(8),
            child: Image.asset(assetPath, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: kRomagnaDarkGray.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _DocumentButton extends StatelessWidget {
  const _DocumentButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTapUrl,
    this.onTap,
    this.trailingIcon = Icons.open_in_new_rounded,
  }) : assert(onTapUrl != null || onTap != null);

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? onTapUrl;
  final VoidCallback? onTap;
  final IconData trailingIcon;

  Future<void> _handleTap() async {
    if (onTap != null) {
      onTap!();
      return;
    }
    final uri = Uri.parse(onTapUrl!);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.35,
                        color: kRomagnaDarkGray.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(trailingIcon, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _StrikeAreaCard extends StatelessWidget {
  const _StrikeAreaCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF9A3412),
            ),
          ),
          const SizedBox(height: 6),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $line',
                style: GoogleFonts.inter(
                  fontSize: 12.8,
                  height: 1.35,
                  color: const Color(0xFF9A3412).withValues(alpha: 0.88),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
