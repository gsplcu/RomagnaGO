import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'servizio_clienti_page.dart';
import 'navette_bussi_data.dart';
import 'romagna_brand.dart';

const _kPagePadding = 16.0;
const _kCardPadding = 12.0;
const _kBlockGap = 12.0;
const _kTightGap = 6.0;
const _kSectionTopGap = 24.0;
const _kCardRadius = 12.0;
const _kMyStartLogoSize = 56.0;

class NavetteBusSiPage extends StatelessWidget {
  const NavetteBusSiPage({super.key});

  Future<void> _openUri(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire ${uri.toString()}')),
      );
    }
  }

  Future<void> _openMyStartAppOrStore({required bool ios}) async {
    if (!ios) {
      if (await canLaunchUrl(kBusSiAppUri)) {
        final opened = await launchUrl(
          kBusSiAppUri,
          mode: LaunchMode.externalApplication,
        );
        if (opened) return;
      }
      final market = Uri.parse('market://details?id=$kBusSiPlayStoreId');
      if (await canLaunchUrl(market)) {
        await launchUrl(market, mode: LaunchMode.externalApplication);
        return;
      }
      await launchUrl(
        Uri.parse(
          'https://play.google.com/store/apps/details?id=$kBusSiPlayStoreId',
        ),
        mode: LaunchMode.externalApplication,
      );
      return;
    }

    if (await canLaunchUrl(kBusSiAppUri)) {
      final opened = await launchUrl(
        kBusSiAppUri,
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    }
    await launchUrl(
      Uri.parse(kBusSiAppStoreUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  void _openContattiPage(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ServizioClientiPage()),
    );
  }

  void _onHelpLinkTap(BuildContext context, BusSiHelpLink link) {
    if (link.opensContattiPage) {
      _openContattiPage(context);
      return;
    }
    final uri = link.uri;
    if (uri != null) _openUri(context, uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BusSiColors.accentSoft,
      appBar: AppBar(
        title: Text(
          'BusSì',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          _kPagePadding,
          12,
          _kPagePadding,
          28,
        ),
        children: [
          const _HeaderSection(),
          const SizedBox(height: _kSectionTopGap),
          _InBreveSection(),
          const SizedBox(height: _kSectionTopGap),
          _OrariSection(),
          const SizedBox(height: _kSectionTopGap),
          _BigliettiSection(),
          const SizedBox(height: _kSectionTopGap),
          _MyStartSection(onOpenStore: _openMyStartAppOrStore),
          _HelpSection(
            onOpenUri: (u) => _openUri(context, u),
            onHelpLink: (l) => _onHelpLinkTap(context, l),
          ),
        ],
      ),
    );
  }
}

class _BusSiStyles {
  static TextStyle title({double size = 22}) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: BusSiColors.accentDark,
    height: 1.25,
  );

  static TextStyle sectionTitle() => title(size: 24);

  static TextStyle body({Color? color, double size = 14}) => GoogleFonts.inter(
    fontSize: size,
    height: 1.45,
    color: color ?? BusSiColors.text.withValues(alpha: 0.88),
  );

  static TextStyle label() => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: BusSiColors.accentDark,
  );
}

Widget _surfaceCard({required Widget child}) {
  return DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_kCardRadius),
      border: Border.all(color: BusSiColors.cardBorder),
      boxShadow: [
        BoxShadow(
          color: BusSiColors.accent.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Padding(padding: const EdgeInsets.all(_kCardPadding), child: child),
  );
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(_kCardRadius),
          child: Image.asset(
            kBusSiLogoAsset,
            width: double.infinity,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: _kBlockGap),
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [_chip('Servizio a chiamata'), _chip('Cesena')],
              ),
              const SizedBox(height: _kTightGap),
              Text(
                'BusSì – Trasporto pubblico a chiamata',
                style: _BusSiStyles.title(size: 21),
              ),
              const SizedBox(height: _kTightGap),
              Text(
                'BusSì è il servizio di trasporto pubblico a chiamata attivo dal 14 novembre 2022, che collega Cesena Ovest e Cesena Est con il centro cittadino.',
                style: _BusSiStyles.body(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: BusSiColors.accentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: BusSiColors.cardBorder),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: BusSiColors.accentDark,
        ),
      ),
    );
  }
}

class _InBreveSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('In breve', style: _BusSiStyles.sectionTitle()),
        const SizedBox(height: _kBlockGap),
        romagnaHelpImageFrame(
          child: Image.asset(
            kBusSiInBreveAsset,
            width: double.infinity,
            fit: BoxFit.fitWidth,
          ),
        ),
      ],
    );
  }
}

class _OrariSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Orari del servizio', style: _BusSiStyles.sectionTitle()),
        const SizedBox(height: _kBlockGap),
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.wb_sunny_rounded,
                    size: 20,
                    color: BusSiColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Orario estivo', style: _BusSiStyles.label()),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(kBusSiSummerPeriodLabel, style: _BusSiStyles.body(size: 13)),
              const SizedBox(height: 10),
              Text(
                'Nel periodo estivo il servizio è attivo nei seguenti orari:',
                style: _BusSiStyles.body(size: 13),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _timeSlot(
                      label: 'Mattina',
                      hours: kBusSiSummerMorning,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _timeSlot(
                      label: 'Pomeriggio',
                      hours: kBusSiSummerAfternoon,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _timeSlot({required String label, required String hours}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: BusSiColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BusSiColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: _BusSiStyles.label()),
          const SizedBox(height: 4),
          Text(
            hours,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: BusSiColors.accent,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _BigliettiSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Biglietti e abbonamenti', style: _BusSiStyles.sectionTitle()),
        const SizedBox(height: _kBlockGap),
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Il servizio è accessibile con biglietto da 0,50 € per ogni corsa.',
                style: _BusSiStyles.body(),
              ),
              const SizedBox(height: 10),
              _bullet(
                'Accedendo al servizio BusSì con il biglietto da 0,50 € è possibile viaggiare per 60 minuti anche sui servizi di trasporto pubblico locale (TPL). Qualora, entro lo stesso intervallo di 60 minuti, si utilizzi nuovamente il servizio BusSì, è previsto il pagamento di un ulteriore biglietto da 0,50 €.',
              ),
              _bullet(
                'Il titolo di viaggio BusSì viene rilasciato dal conducente. Prossimamente sarà inserito digitalmente nei servizi dell\'app MyStart.',
              ),
              _bullet(
                'I bambini al di sotto dei 5 anni viaggiano gratuitamente, ma devono essere comunque indicati nella prenotazione.',
              ),
              const SizedBox(height: 6),
              Text(
                'L\'abbonamento al trasporto pubblico valido nell\'area urbana di Cesena, mensile o annuale, inclusi gli abbonamenti Salta su!, consente di accedere al servizio BusSì senza costi aggiuntivi.',
                style: _BusSiStyles.body(size: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'L\'abbonamento su tessera Mi Muovo o su tessera ferroviaria Unica deve essere mostrato al conducente al momento della salita a bordo bus.',
                style: _BusSiStyles.body(size: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: BusSiColors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: _BusSiStyles.body(size: 13))),
        ],
      ),
    );
  }
}

class _MyStartSection extends StatelessWidget {
  const _MyStartSection({required this.onOpenStore});

  final Future<void> Function({required bool ios}) onOpenStore;

  @override
  Widget build(BuildContext context) {
    final ios =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Prenota e viaggia con My Start',
          style: _BusSiStyles.sectionTitle(),
        ),
        const SizedBox(height: _kBlockGap),
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      kBusSiMyStartLogoAsset,
                      width: _kMyStartLogoSize,
                      height: _kMyStartLogoSize,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: _kBlockGap),
                  Expanded(
                    child: Text(
                      'Scarica gratuitamente l\'app MyStart per usufruire del servizio: cerca «My Start» sullo store o apri l\'app se già installata.',
                      style: _BusSiStyles.body(size: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _kBlockGap),
              Text('BusSì: come funziona', style: _BusSiStyles.label()),
              const SizedBox(height: 6),
              Text(kBusSiHowItWorksIntro, style: _BusSiStyles.body(size: 13)),
              const SizedBox(height: 8),
              for (final mode in kBusSiTravelModes) ...[
                _modeBlock(mode.title, mode.body),
                const SizedBox(height: 6),
              ],
              Text(kBusSiHowItWorksFooter, style: _BusSiStyles.body(size: 13)),
              const SizedBox(height: _kBlockGap),
              Text('Viaggia Ora', style: _BusSiStyles.label()),
              const SizedBox(height: 6),
              Text(
                'Per le richieste in tempo reale, la soluzione di viaggio viene rappresentata su una mappa che mostra chiaramente:',
                style: _BusSiStyles.body(size: 13),
              ),
              const SizedBox(height: 6),
              for (final item in kBusSiViaggiaOraBullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: _BusSiStyles.body(size: 13)),
                      Expanded(
                        child: Text(item, style: _BusSiStyles.body(size: 13)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Text(kBusSiViaggiaOraFooter, style: _BusSiStyles.body(size: 13)),
              const SizedBox(height: _kBlockGap),
              Text('Pianifica Viaggio', style: _BusSiStyles.label()),
              const SizedBox(height: 6),
              Text(
                kBusSiPianificaViaggioBody,
                style: _BusSiStyles.body(size: 13),
              ),
              const SizedBox(height: _kBlockGap),
              if (!ios)
                _storeButton(
                  label: 'Google Play Store',
                  icon: Icons.android_rounded,
                  onTap: () => onOpenStore(ios: false),
                ),
              if (!ios) const SizedBox(height: _kTightGap),
              _storeButton(
                label: 'Apple Store',
                icon: Icons.apple_rounded,
                onTap: () => onOpenStore(ios: true),
              ),
              if (ios) ...[
                const SizedBox(height: _kTightGap),
                _storeButton(
                  label: 'Google Play Store',
                  icon: Icons.android_rounded,
                  onTap: () => onOpenStore(ios: false),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _modeBlock(String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 16,
          color: BusSiColors.accent,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: _BusSiStyles.body(size: 13),
              children: [
                TextSpan(
                  text: title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' $body'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _storeButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: BusSiColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: const Size(double.infinity, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_kCardRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.onOpenUri, required this.onHelpLink});

  final ValueChanged<Uri> onOpenUri;
  final ValueChanged<BusSiHelpLink> onHelpLink;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: _kSectionTopGap),
          child: Text('Serve aiuto?', style: _BusSiStyles.sectionTitle()),
        ),
        const SizedBox(height: _kBlockGap),
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Informazioni e assistenza', style: _BusSiStyles.label()),
              const SizedBox(height: 6),
              Text(kBusSiAssistenzaIntro, style: _BusSiStyles.body(size: 13)),
              const SizedBox(height: 10),
              _assistenzaRow(
                icon: Icons.mail_outline_rounded,
                label: kBusSiAssistenzaEmail,
                onTap: () => onOpenUri(kBusSiAssistenzaEmailUri),
              ),
              const SizedBox(height: 8),
              _assistenzaRow(
                icon: Icons.phone_rounded,
                label: kBusSiAssistenzaPhone,
                onTap: () => onOpenUri(kBusSiAssistenzaPhoneUri),
              ),
              const SizedBox(height: 6),
              Text(
                kBusSiAssistenzaPhoneHours,
                style: _BusSiStyles.body(
                  size: 12,
                  color: BusSiColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < kBusSiStandardHelpLinks.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _HelpCard(
            link: kBusSiStandardHelpLinks[i],
            onTap: () => onHelpLink(kBusSiStandardHelpLinks[i]),
          ),
        ],
      ],
    );
  }

  Widget _assistenzaRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(icon, size: 18, color: BusSiColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BusSiColors.accentDark,
                    decoration: TextDecoration.underline,
                    decorationColor: BusSiColors.accent.withValues(alpha: 0.5),
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

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.link, required this.onTap});

  final BusSiHelpLink link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: Icon(link.icon, size: 20, color: BusSiColors.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      link.title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.15,
                        color: BusSiColors.accentDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      link.subtitle,
                      style: _BusSiStyles.body(
                        size: 11.5,
                        color: BusSiColors.text.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: BusSiColors.accent.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
