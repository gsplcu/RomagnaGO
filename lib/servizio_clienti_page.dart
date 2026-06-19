// Assistenza Start Romagna — contenuti da startromagna.it/servizio-clienti/

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'romagna_brand.dart';
import 'start_content/start_content_id.dart';
import 'start_content/start_content_screen_mixin.dart';

const String kServizioClientiPageUrl =
    'https://www.startromagna.it/servizio-clienti/';
const String kInfoStartPhoneDisplay = '199.11.55.77';
const String kInfoStartPhoneTel = '199115577';
const String kWhatsAppDisplay = '331.65.66.555';
const String kWhatsAppUrl = 'https://wa.me/393316566555';
const String kServizioClientiEmail = 'servizioclienti@startromagna.it';
const String kRichiediInfoUrl =
    'https://www.startromagna.it/assistenza/richiedi-info/';
const String kReclamiUrl = 'https://www.startromagna.it/reclami/';
const String kSegnalazioneUrl =
    'https://www.startromagna.it/fai-una-segnalazione/';
const String kOggettiSmarritiUrl =
    'https://www.startromagna.it/oggetti-smarriti/';
const String kTelegramStartUrl =
    'https://www.startromagna.it/telegram-start-romagna/';
const String kTelegramFcUrl = 'https://t.me/StartRomagnaInfoFC';
const String kTelegramRaUrl = 'https://t.me/StartRomagnaInfoRA';
const String kTelegramRnUrl = 'https://t.me/StartRomagnaInfoRN';
const String kFacebookUrl = 'https://www.facebook.com/StartRomagna';
const String kInstagramUrl = 'https://www.instagram.com/startromagna/';
const String kLinkedInUrl =
    'https://www.linkedin.com/company/start-romagna-s-p-a-';

Future<void> openStartRomagnaUrl(String url) async {
  final uri = Uri.parse(url);
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

Future<void> _openTel(String digits) async {
  try {
    await launchUrl(Uri(scheme: 'tel', path: digits));
  } catch (_) {}
}

Future<void> _openEmail(String address) async {
  try {
    await launchUrl(Uri(scheme: 'mailto', path: address));
  } catch (_) {}
}

/// Apre la schermata Contatti (stessa voce di Altro → Contatti).
void openContattiPage(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const ServizioClientiPage()),
  );
}

/// Pagina contatti / servizio clienti (menu Altro → Contatti, navette, …).
class ServizioClientiPage extends StatelessWidget {
  const ServizioClientiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Contatti',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: const ServizioClientiBody(),
    );
  }
}

/// Blocco assistenza Start (riutilizzato in Altro → Aiuto).
class ServizioClientiBody extends StatefulWidget {
  const ServizioClientiBody({super.key});

  @override
  State<ServizioClientiBody> createState() => _ServizioClientiBodyState();
}

class _ServizioClientiBodyState extends State<ServizioClientiBody>
    with StartContentScreenMixin<ServizioClientiBody> {
  @override
  StartContentId get startContentId => StartContentId.servizioClienti;

  @override
  Widget build(BuildContext context) {
    if (contentLoading && content.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: _ServizioClientiSections(content).sections(),
    );
  }
}

class _ServizioClientiSections {
  const _ServizioClientiSections(this.content);

  final Map<String, dynamic> content;

  String _txt(String key, String fallback) {
    final v = content[key];
    if (v == null) return fallback;
    final s = '$v';
    return s.isEmpty ? fallback : s;
  }

  List<String> _bullets(String key, List<String> fallback) {
    final raw = content[key];
    if (raw is! List || raw.isEmpty) return fallback;
    return [for (final v in raw) '$v'];
  }

  TextStyle _bodyStyle() => GoogleFonts.inter(
    fontSize: 13.5,
    height: 1.42,
    color: kRomagnaDarkGray.withValues(alpha: 0.78),
  );

  TextStyle _captionStyle() => GoogleFonts.inter(
    fontSize: 12,
    height: 1.38,
    color: kRomagnaDarkGray.withValues(alpha: 0.62),
  );

  List<Widget> sections() {
    return [
      const _ServizioClientiHero(),
      const SizedBox(height: 14),
      _QuickActionsRow(
        onRichiediInfo: () => openStartRomagnaUrl(kRichiediInfoUrl),
        onWhatsApp: () => openStartRomagnaUrl(kWhatsAppUrl),
        onSegnalazione: () => openStartRomagnaUrl(kSegnalazioneUrl),
        onOggettiSmarriti: () => openStartRomagnaUrl(kOggettiSmarritiUrl),
      ),
      const SizedBox(height: 18),
      Text(
        'Come contattare il Servizio Clienti',
        style: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: kRomagnaDarkGray,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        _txt(
          'intro',
          'Puoi parlare con Start Romagna attraverso diversi canali, '
              'scegliendo quello più adatto alle tue esigenze: telefono, WhatsApp, '
              'email, modulo online o social network.',
        ),
        style: _bodyStyle(),
      ),
      const SizedBox(height: 14),
      _ServizioSectionCard(
        icon: Icons.phone_in_talk_rounded,
        kicker: 'Telefono',
        title: 'Info START ${_txt('infoStartPhoneDisplay', kInfoStartPhoneDisplay)}',
        accent: kRomagnaPrimary,
        children: [
          Text(_txt('phoneIntro', 'Numero telefonico unico per informazioni su servizi e orari del '
            'trasporto pubblico locale nei bacini di Forlì-Cesena, Ravenna e Rimini.'), style: _bodyStyle()),
          const SizedBox(height: 10),
          _BulletList(items: _bullets('phoneBullets', const [
            'Informazioni su linee, orari, percorsi, titoli di viaggio e assistenza generale.',
            'Tariffa massima 0,1188 € al minuto + IVA da ogni telefono fisso.',
          ])),
          const SizedBox(height: 6),
          Text(
            _txt(
              'phoneCaption',
              'Il costo effettivo della chiamata può variare in base al tuo operatore. '
                  'Verifica sempre le condizioni della tua offerta.',
            ),
            style: _captionStyle(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openTel(_txt('infoStartPhoneTel', kInfoStartPhoneTel)),
              icon: const Icon(Icons.call_rounded, size: 18),
              label: Text(
                'Chiama ora',
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
      _ServizioSectionCard(
        icon: Icons.chat_rounded,
        kicker: 'Digitale',
        title: 'WhatsApp, email e modulo online',
        accent: const Color(0xFF25D366),
        children: [
          Text(_txt('digitalIntro', 'Canali digitali per richiedere informazioni, inviare reclami o '
            'segnalazioni senza dover telefonare.'), style: _bodyStyle()),
          const SizedBox(height: 10),
          _BulletList(items: _bullets('digitalBullets', [
            'WhatsApp — $kWhatsAppDisplay: informazioni su linee, orari e percorsi. Attivo h24, 7 giorni su 7; nelle ore di chiusura del servizio clienti risponde Guido, il chatbot di Start Romagna.',
            'Email — $kServizioClientiEmail',
            'Reclami — per reclami o segnalazioni utilizza il modulo online dedicato.',
          ])),
          const SizedBox(height: 12),
          _ContactLinkTile(
            icon: Icons.chat_rounded,
            title: 'Scrivi su WhatsApp',
            subtitle: _txt('whatsAppDisplay', kWhatsAppDisplay),
            onTap: () => openStartRomagnaUrl(kWhatsAppUrl),
          ),
          const SizedBox(height: 8),
          _ContactLinkTile(
            icon: Icons.mail_outline_rounded,
            title: 'Scrivi una email',
            subtitle: _txt('servizioClientiEmail', kServizioClientiEmail),
            onTap: () => _openEmail(kServizioClientiEmail),
          ),
          const SizedBox(height: 8),
          _ContactLinkTile(
            icon: Icons.forum_outlined,
            title: 'Reclami o segnalazioni',
            subtitle: 'Modulo online dedicato',
            onTap: () => openStartRomagnaUrl(kReclamiUrl),
          ),
        ],
      ),
      _ServizioSectionCard(
        icon: Icons.share_rounded,
        kicker: 'Social',
        title: 'Canali social',
        accent: const Color(0xFF2563EB),
        children: [
          Text(_txt('socialIntro', 'Segui Start Romagna sui social per aggiornamenti, novità di servizio '
            'e contenuti informativi.'), style: _bodyStyle()),
          const SizedBox(height: 10),
          _ContactLinkTile(
            icon: Icons.facebook_rounded,
            title: 'Facebook',
            subtitle: 'Start Romagna',
            onTap: () => openStartRomagnaUrl(kFacebookUrl),
          ),
          const SizedBox(height: 8),
          _ContactLinkTile(
            icon: Icons.camera_alt_outlined,
            title: 'Instagram',
            subtitle: '@startromagna',
            onTap: () => openStartRomagnaUrl(kInstagramUrl),
          ),
          const SizedBox(height: 8),
          _ContactLinkTile(
            icon: Icons.business_center_outlined,
            title: 'LinkedIn',
            subtitle: 'Start Romagna',
            onTap: () => openStartRomagnaUrl(kLinkedInUrl),
          ),
        ],
      ),
      _ServizioSectionCard(
        icon: Icons.smart_toy_outlined,
        kicker: 'Chatbot',
        title: 'Guido, il chatbot di Start Romagna',
        accent: const Color(0xFF7C3AED),
        children: [
          for (final p in _bullets('chatbotParagraphs', const [
            'Quando il Servizio Clienti non è presidiato dagli operatori, il numero '
                'WhatsApp viene gestito da Guido, il chatbot che ti aiuta a trovare '
                'rapidamente informazioni su linee, orari e percorsi.',
            'Puoi scrivere a Guido in qualsiasi momento. Nelle fasce di apertura del '
                'servizio clienti potrai essere preso in carico da un operatore se la tua '
                'richiesta richiede un supporto dedicato.',
          ])) ...[
            Text(p, style: _bodyStyle()),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => openStartRomagnaUrl(kWhatsAppUrl),
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: Text(
                'Apri WhatsApp',
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
      _ServizioSectionCard(
        icon: Icons.send_rounded,
        kicker: 'Telegram',
        title: 'Telegram Start Romagna',
        accent: const Color(0xFF0088CC),
        children: [
          Text(
            _txt(
              'telegramIntro',
              'Iscrivendoti ai canali Telegram puoi ricevere aggiornamenti in tempo reale '
                  'su deviazioni, modifiche temporanee di percorso e altre informazioni di '
                  'servizio nel bacino che ti interessa.',
            ),
            style: _bodyStyle(),
          ),
          const SizedBox(height: 12),
          _TelegramBasinTile(
            provinceCode: 'FC',
            title: 'Forlì-Cesena',
            description:
                'Notifiche sulle principali variazioni del servizio bus nel bacino di Forlì-Cesena.',
            channelUrl: kTelegramFcUrl,
          ),
          const SizedBox(height: 8),
          _TelegramBasinTile(
            provinceCode: 'RA',
            title: 'Ravenna',
            description:
                'Avvisi e informazioni sulla rete di trasporto nel bacino di Ravenna.',
            channelUrl: kTelegramRaUrl,
          ),
          const SizedBox(height: 8),
          _TelegramBasinTile(
            provinceCode: 'RN',
            title: 'Rimini',
            description:
                'Aggiornamenti sulle linee e le deviazioni nell’area di Rimini.',
            channelUrl: kTelegramRnUrl,
          ),
          const SizedBox(height: 10),
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
            ),
            onPressed: () => openStartRomagnaUrl(kTelegramStartUrl),
            child: Text(
              'Pagina ufficiale Telegram Start Romagna',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: kRomagnaPrimary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Center(
        child: TextButton.icon(
          onPressed: () => openStartRomagnaUrl(kServizioClientiPageUrl),
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: Text(
            'Apri pagina web Servizio Clienti',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ];
  }
}

class _ServizioClientiHero extends StatelessWidget {
  const _ServizioClientiHero();

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
            'Info e assistenza Start Romagna',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Un unico punto di contatto per informazioni su linee, orari, percorsi, '
            'reclami e segnalazioni nei bacini di Forlì-Cesena, Ravenna e Rimini.',
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

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onRichiediInfo,
    required this.onWhatsApp,
    required this.onSegnalazione,
    required this.onOggettiSmarriti,
  });

  final VoidCallback onRichiediInfo;
  final VoidCallback onWhatsApp;
  final VoidCallback onSegnalazione;
  final VoidCallback onOggettiSmarriti;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _QuickChip(
          icon: Icons.info_outline_rounded,
          label: 'Richiedi info',
          onTap: onRichiediInfo,
        ),
        _QuickChip(
          icon: Icons.chat_rounded,
          label: 'WhatsApp',
          onTap: onWhatsApp,
        ),
        _QuickChip(
          icon: Icons.report_outlined,
          label: 'Segnalazione',
          onTap: onSegnalazione,
        ),
        _QuickChip(
          icon: Icons.work_outline_rounded,
          label: 'Oggetti smarriti',
          onTap: onOggettiSmarriti,
        ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kRomagnaPrimary.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: kRomagnaPrimary),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: kRomagnaDarkGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServizioSectionCard extends StatelessWidget {
  const _ServizioSectionCard({
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

class _ContactLinkTile extends StatelessWidget {
  const _ContactLinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Icon(icon, size: 22, color: kRomagnaPrimary),
              const SizedBox(width: 12),
              Expanded(
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
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: kRomagnaDarkGray.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: kRomagnaPrimary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TelegramBasinBadge extends StatelessWidget {
  const _TelegramBasinBadge({required this.provinceCode});

  final String provinceCode;

  @override
  Widget build(BuildContext context) {
    final (fill, foreground) = switch (provinceCode) {
      'FC' => (
        const Color(0xFF059669).withValues(alpha: 0.14),
        const Color(0xFF047857),
      ),
      'RA' => (kRomagnaPrimary.withValues(alpha: 0.14), kRomagnaPrimary),
      'RN' => (const Color(0xFFFFE4E6), const Color(0xFFC62828)),
      _ => (
        const Color(0xFF0088CC).withValues(alpha: 0.14),
        const Color(0xFF0088CC),
      ),
    };

    return SizedBox(
      width: 40,
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: foreground.withValues(alpha: 0.35)),
        ),
        child: Center(
          child: Text(
            provinceCode,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.25,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _TelegramBasinTile extends StatelessWidget {
  const _TelegramBasinTile({
    required this.provinceCode,
    required this.title,
    required this.description,
    required this.channelUrl,
  });

  final String provinceCode;
  final String title;
  final String description;
  final String channelUrl;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openStartRomagnaUrl(channelUrl),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TelegramBasinBadge(provinceCode: provinceCode),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
                        fontSize: 12.5,
                        height: 1.38,
                        color: kRomagnaDarkGray.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Iscriviti al canale',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kRomagnaPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: kRomagnaPrimary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
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
