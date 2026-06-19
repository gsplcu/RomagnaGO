// Menu «Altro»: navigazione verso account, linee, impostazioni e segnaposto.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'altro_account_settings.dart';
import 'app_settings.dart';
import 'avvisi_telegram_intro_page.dart';
import 'corse_non_garantite_page.dart';
import 'preferiti_page.dart';
import 'linee_percorsi.dart';
import 'login_page.dart';
import 'quick_addresses.dart';
import 'romagna_brand.dart';
import 'servizio_clienti_page.dart';
import 'settings_hub_page.dart';

class AltroMenuPage extends StatelessWidget {
  const AltroMenuPage({
    super.key,
    required this.settingsController,
    required this.quickAddressesListenable,
    required this.onSettingsApply,
  });

  final AppSettingsController settingsController;
  final ValueListenable<QuickAddressesState> quickAddressesListenable;
  final SettingsApplyCallback onSettingsApply;

  @override
  Widget build(BuildContext context) {
    Widget tile({
      required IconData icon,
      required String title,
      String? subtitle,
      VoidCallback? onTap,
      bool enabled = true,
    }) {
      return romagnaMenuInkRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: onTap,
        enabled: enabled,
      );
    }

    void openAccount() {
      final logged = FirebaseAuth.instance.currentUser;
      if (logged == null) {
        showDialog<void>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: Text(
                  'Sei in modalità ospite',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                content: Text(
                  'Accedi o registrati per gestire il tuo profilo e le preferenze legate all’account.',
                  style: GoogleFonts.inter(height: 1.35),
                ),
                actions: [
                  FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).pushAndRemoveUntil(
                        MaterialPageRoute<void>(
                          builder: (_) => const LoginPage(),
                        ),
                        (route) => false,
                      );
                    },
                    child: Text(
                      'Vai al login',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
        );
        return;
      }
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const AccountProfilePage()),
      );
    }

    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    return Material(
      color: const Color(0xFFFAFAFA),
      child: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: Text(
                'Altro',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: kRomagnaDarkGray,
                ),
              ),
            ),
            tile(
              icon: Icons.person_outline_rounded,
              title: 'Il mio account',
              onTap: openAccount,
            ),
            tile(
              icon: Icons.star_border_rounded,
              title: 'Preferiti',
              subtitle:
                  isLoggedIn
                      ? 'Fermate e linee'
                      : 'Accedi per usare i preferiti',
              enabled: isLoggedIn,
              onTap:
                  isLoggedIn
                      ? () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const PreferitiPage(),
                        ),
                      )
                      : null,
            ),
            tile(
              icon: Icons.alt_route_rounded,
              title: 'Linee e percorsi',
              onTap:
                  () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const LineeBaciniPage(),
                    ),
                  ),
            ),
            tile(
              icon: Icons.notifications_none_rounded,
              title: 'Avvisi',
              onTap:
                  () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const AvvisiTelegramIntroPage(),
                    ),
                  ),
            ),
            tile(
              icon: Icons.event_busy_rounded,
              title: 'Corse non garantite',
              subtitle: 'Aggiornamenti per bacino e giorno',
              onTap:
                  () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const CorseNonGarantitePage(),
                    ),
                  ),
            ),
            tile(
              icon: Icons.call_outlined,
              title: 'Contatti',
              subtitle: 'Servizio Clienti Start Romagna',
              onTap:
                  () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const ServizioClientiPage(),
                    ),
                  ),
            ),
            tile(
              icon: Icons.help_outline_rounded,
              title: 'Aiuto',
              subtitle: 'Guida rapida alle funzioni principali',
              onTap:
                  () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const AiutoPage()),
                  ),
            ),
            tile(
              icon: Icons.copyright_rounded,
              title: 'Crediti',
              subtitle: 'Attribuzioni',
              onTap:
                  () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const MapCreditsPage(),
                    ),
                  ),
            ),
            const Divider(height: 24),
            tile(
              icon: Icons.tune_rounded,
              title: 'Impostazioni',
              onTap:
                  () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder:
                          (_) => SettingsHubPage(
                            initialSettings: settingsController.value,
                            initialQuickAddresses: quickAddressesListenable.value,
                            onApply: onSettingsApply,
                          ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class AiutoPage extends StatelessWidget {
  const AiutoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Aiuto',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Text(
            'Come funziona RomagnaGO',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: kRomagnaDarkGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Questa guida è pensata per aiutarti a usare rapidamente le funzioni disponibili in app: mappa, fermate, linee, percorsi, avvisi e gestione.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.4,
              color: kRomagnaDarkGray.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 14),
          const _HelpSectionCard(
            icon: Icons.map_rounded,
            title: 'Mappa e posizione',
            description:
                'Apri la sezione principale per vedere la mappa. Puoi centrare la tua posizione e muoverti nella zona per cercare fermate vicine.',
            imageAssetPath: 'assets/aiuto/mappa.png',
          ),
          const _HelpSectionCard(
            icon: Icons.directions_bus_rounded,
            title: 'Card fermata',
            description:
                'Tocca un marker fermata per aprire la card informativa: nome, ID fermata, località, accessibilità disabili e zona tariffaria. In basso trovi invece tutte le informazioni relative alle linee in transito, gli orari e le prossime partenze. Chiudi cliccando ovunque fuori dalla card.',
            imageAssetPath: 'assets/aiuto/card.png',
          ),
          const _HelpSectionCard(
            icon: Icons.alt_route_rounded,
            title: 'Linee e percorsi',
            description:
                'Dal menu Altro entra in Linee e percorsi per navigare linee e tracciati disponibili nei diversi bacini.',
            imageAssetPath: 'assets/aiuto/linee.png',
          ),
          const _HelpSectionCard(
            icon: Icons.notifications_active_outlined,
            title: 'Avvisi e aggiornamenti',
            description:
                'Nella sezione Avvisi trovi comunicazioni importanti su servizio, deviazioni o eventuali modifiche operative.',
            imageAssetPath: 'assets/aiuto/avvisi.png',
          ),
          const _HelpSectionCard(
            icon: Icons.person_outline_rounded,
            title: 'Account, preferiti e impostazioni',
            description:
                'Nel menu Altro puoi accedere al profilo, salvare preferiti e gestire le impostazioni, incluse le fermate visibili sulla mappa.',
            imageAssetPath: 'assets/aiuto/altro.png',
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: kRomagnaPrimary.withValues(alpha: 0.22),
              ),
            ),
            child: Text(
              'Suggerimento: se sei in modalita ospite puoi comunque esplorare la mappa; accedendo all\'account sblocchi anche tutte le altre funzioni personali.',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.4,
                color: kRomagnaDarkGray.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSectionCard extends StatelessWidget {
  const _HelpSectionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.imageAssetPath,
  });

  final IconData icon;
  final String title;
  final String description;
  final String imageAssetPath;

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
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: kRomagnaPrimary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: kRomagnaPrimary),
              ),
              const SizedBox(width: 10),
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
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              height: 1.42,
              color: kRomagnaDarkGray.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          romagnaHelpImageFrame(
            child: Image.asset(imageAssetPath, fit: BoxFit.contain),
          ),
          const SizedBox(height: 8),
          Container(
            alignment: Alignment.centerRight,
            child: Text(
              'Screenshot dimostrativo',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: kRomagnaDarkGray.withValues(alpha: 0.62),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openMapCreditUrl(String url) async {
  final uri = Uri.parse(url);
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Attribuzione testuale dei layer cartografici (non mostrata in sovrimpressione sulla mappa).
class MapCreditsPage extends StatelessWidget {
  const MapCreditsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final body = GoogleFonts.inter(
      fontSize: 14,
      height: 1.45,
      color: kRomagnaDarkGray.withValues(alpha: 0.82),
    );
    final link = GoogleFonts.inter(
      fontSize: 13.5,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: kRomagnaPrimary,
      decoration: TextDecoration.underline,
    );

    Widget block(
      String title,
      String paragraph,
      List<(String label, String url)> links,
    ) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kRomagnaDarkGray,
              ),
            ),
            const SizedBox(height: 8),
            Text(paragraph, style: body),
            for (final e in links) ...[
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () => _openMapCreditUrl(e.$2),
                child: Text(e.$1, style: link),
              ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Crediti mappe',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        children: [
          Text(
            'RomagnaGO usa mappe online soggette a licenza. Le diciture non compaiono sulla mappa per scelta di interfaccia; qui trovi i riferimenti obbligatori e i link alle pagine ufficiali.',
            style: body,
          ),
          const SizedBox(height: 20),
          block(
            'Humanitarian (HOT)',
            'Tile «HOT» da OpenStreetMap France nello stile Humanitarian OpenStreetMap Team, '
                'orientato a contesti umanitari e lettura rapida su dati © OpenStreetMap.',
            [
              ('Humanitarian OpenStreetMap Team', 'https://www.hotosm.org/'),
              (
                'Diritti e licenza OpenStreetMap',
                'https://www.openstreetmap.org/copyright',
              ),
            ],
          ),
          block(
            'Satellite',
            'Immagini «World Imagery» © Esri, Maxar, Earthstar Geographics e contributori della comunità GIS, secondo le condizioni Esri per l’uso delle mappe di base.',
            [
              (
                'Copyright e marchi Esri',
                'https://www.esri.com/en-us/legal/copyright-trademarks',
              ),
            ],
          ),
          block(
            'CyclOSM',
            'Tile ospitate da OpenStreetMap France, progetto CyclOSM su dati © OpenStreetMap e contributori. '
                'Lo stile enfatizza ciclabilità, reti e rilievo rispetto alla mappa standard.',
            [
              ('Progetto CyclOSM', 'https://www.cyclosm.org/'),
              (
                'Diritti e licenza OpenStreetMap',
                'https://www.openstreetmap.org/copyright',
              ),
            ],
          ),
          block(
            'Mappa chiara',
            'Stile «light» fornito da CARTO su dati OpenStreetMap. '
                'OpenStreetMap è © dei collaboratori OSM; le tile e lo stile seguono le condizioni CARTO.',
            [
              (
                'Diritti e licenza OpenStreetMap',
                'https://www.openstreetmap.org/copyright',
              ),
              ('Note legali CARTO', 'https://carto.com/legal/'),
            ],
          ),
          block(
            'Mappa scura (Dark Matter)',
            'Stile «dark_all» CARTO su dati OpenStreetMap: stesse basi giuridiche della mappa chiara, con tema scuro per ridurre abbagliamento e consumo su schermi OLED.',
            [
              (
                'Diritti e licenza OpenStreetMap',
                'https://www.openstreetmap.org/copyright',
              ),
              ('Note legali CARTO', 'https://carto.com/legal/'),
            ],
          ),
        ],
      ),
    );
  }
}
