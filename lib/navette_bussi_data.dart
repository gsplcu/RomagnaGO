/// Contenuti da [BusSì – Start Romagna](https://www.startromagna.it/bussi/).
library;

import 'package:flutter/material.dart';

import 'start_content/navetta_content_sync.dart';
import 'start_content/start_content_id.dart';

/// Palette pagina BusSì (viola ufficiale).
abstract final class BusSiColors {
  static const accent = Color(0xFF662580);
  static const accentDark = Color(0xFF4F1D63);
  static const accentSoft = Color(0xFFF7F2FA);
  static const cardBorder = Color(0xFFD4B8DE);
  static const text = Color(0xFF1F2937);
  static const textMuted = Color(0xFF6B7280);
  static const surface = Color(0xFFFAFAFA);
}

const kBusSiLogoAsset = 'assets/logo-busSi-1.png';
const kBusSiInBreveAsset = 'assets/BusSi_page2-3.png';
const kBusSiMyStartLogoAsset = 'assets/mystart-logo.png';

const kBusSiPlayStoreId = 'it.infomobility.mystart';
const kBusSiAppStoreUrl =
    'https://apps.apple.com/it/app/my-start-romagna/id1571409384';
final kBusSiAppUri = Uri(scheme: 'it.infomobility.mystart');

class BusSiHelpLink {
  const BusSiHelpLink({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.uri,
    this.opensContattiPage = false,
  }) : assert(uri != null || opensContattiPage);

  final String title;
  final String subtitle;
  final IconData icon;
  final Uri? uri;
  final bool opensContattiPage;
}

/// Canali Start Romagna (stesso schema altre pagine navetta).
final kBusSiStandardHelpLinks = [
  BusSiHelpLink(
    title: 'Telefono',
    subtitle: '199.11.55.77',
    uri: Uri(scheme: 'tel', path: '199115577'),
    icon: Icons.phone_rounded,
  ),
  BusSiHelpLink(
    title: 'WhatsApp',
    subtitle: 'Chatta con noi',
    uri: Uri.parse('https://wa.me/393316566555'),
    icon: Icons.chat_rounded,
  ),
  BusSiHelpLink(
    title: 'Servizio Clienti',
    subtitle: 'Vai ai contatti',
    icon: Icons.support_agent_rounded,
    opensContattiPage: true,
  ),
];

const _kBusSiAssistenzaIntroStatic =
    'Per informazioni relativamente a BusSì o assistenza dedicata si può contattare Start Romagna:';

String get kBusSiAssistenzaIntro => NavettaContentSync.text(
  StartContentId.navettaBussi,
  'assistenzaIntro',
  fallback: _kBusSiAssistenzaIntroStatic,
);

String get kBusSiAssistenzaEmail => NavettaContentSync.text(
  StartContentId.navettaBussi,
  'assistenzaEmail',
  fallback: 'bussi@startromagna.it',
);

Uri get kBusSiAssistenzaEmailUri => Uri(
  scheme: 'mailto',
  path: kBusSiAssistenzaEmail,
);

String get kBusSiAssistenzaPhone => NavettaContentSync.text(
  StartContentId.navettaBussi,
  'assistenzaPhone',
  fallback: '800 213480',
);

Uri get kBusSiAssistenzaPhoneUri =>
    Uri(scheme: 'tel', path: kBusSiAssistenzaPhone.replaceAll(' ', ''));

const _kBusSiAssistenzaPhoneHoursStatic =
    'Attivo nei giorni feriali: 8:00–19:00 dal lunedì al venerdì, 8:00–14:00 il sabato.';

String get kBusSiAssistenzaPhoneHours => NavettaContentSync.text(
  StartContentId.navettaBussi,
  'assistenzaPhoneHours',
  fallback: _kBusSiAssistenzaPhoneHoursStatic,
);

const _kBusSiSummerPeriodLabelStatic =
    'Servizio BusSì dal 7 giugno al 14 settembre';

String get kBusSiSummerPeriodLabel => NavettaContentSync.text(
  StartContentId.navettaBussi,
  'summerPeriodLabel',
  fallback: _kBusSiSummerPeriodLabelStatic,
);

String get kBusSiSummerMorning => NavettaContentSync.text(
  StartContentId.navettaBussi,
  'summerMorning',
  fallback: '8:30–12:30',
);

String get kBusSiSummerAfternoon => NavettaContentSync.text(
  StartContentId.navettaBussi,
  'summerAfternoon',
  fallback: '14:30–19:30',
);

const _kBusSiHowItWorksIntroStatic =
    'BusSì prevede due opzioni per utilizzare il servizio:';

String get kBusSiHowItWorksIntro => NavettaContentSync.text(
  StartContentId.navettaBussi,
  'howItWorksIntro',
  fallback: _kBusSiHowItWorksIntroStatic,
);

const _kBusSiTravelModesStatic = [
  (
    title: '«Viaggia Ora»',
    body:
        'Il cliente richiede la prima corsa disponibile per raggiungere la propria destinazione.',
  ),
  (
    title: '«Pianifica Viaggio»',
    body:
        'Prenotazione per un viaggio da effettuare successivamente.',
  ),
];

List<({String title, String body})> get kBusSiTravelModes {
  final raw = NavettaContentSync.mapList(
    StartContentId.navettaBussi,
    'travelModes',
  );
  if (raw.isEmpty) return _kBusSiTravelModesStatic;
  return [
    for (final mode in raw)
      (
        title: '${mode['title'] ?? ''}',
        body: '${mode['body'] ?? ''}',
      ),
  ];
}

const _kBusSiHowItWorksFooterStatic =
    'In entrambi i casi, l\'applicazione propone all\'utente una soluzione di viaggio in base ai veicoli disponibili. L\'utente ha 30 secondi per valutare, ed eventualmente accettare, la soluzione proposta.';

String get kBusSiHowItWorksFooter => NavettaContentSync.text(
  StartContentId.navettaBussi,
  'howItWorksFooter',
  fallback: _kBusSiHowItWorksFooterStatic,
);

const _kBusSiViaggiaOraBulletsStatic = [
  'la fermata di salita',
  'la fermata di discesa',
  'il percorso del veicolo',
  'il tempo di attesa stimato',
  'il tempo per raggiungere a piedi la fermata di salita',
  'il tempo di viaggio stimato',
  'il tempo di arrivo previsto alla destinazione finale',
];

List<String> get kBusSiViaggiaOraBullets => NavettaContentSync.strings(
  StartContentId.navettaBussi,
  'viaggiaOraBullets',
  fallback: _kBusSiViaggiaOraBulletsStatic,
);

const _kBusSiViaggiaOraFooterStatic =
    'Le fermate abilitate al servizio sono contrassegnate da apposita segnaletica BusSì e rilevate digitalmente sull\'applicazione MyStart. Dal 15 settembre 2023 BusSì Area Ovest consente la prenotazione anche per 22 fermate nell\'area di Bertinoro.';

String get kBusSiViaggiaOraFooter => NavettaContentSync.text(
  StartContentId.navettaBussi,
  'viaggiaOraFooter',
  fallback: _kBusSiViaggiaOraFooterStatic,
);

const _kBusSiPianificaViaggioBodyStatic =
    'Per richieste «su prenotazione», all\'utente viene indicato in arancione l\'orario di partenza possibile, quanto più prossimo all\'ora di partenza richiesta. Ad esempio, se un utente ha richiesto di poter partire alle 9:00 ma per quell\'orario non ci sono corse disponibili, l\'applicazione lo informa del fatto che la prima «partenza possibile» sarebbe alle 9:15.';

String get kBusSiPianificaViaggioBody => NavettaContentSync.text(
  StartContentId.navettaBussi,
  'pianificaViaggioBody',
  fallback: _kBusSiPianificaViaggioBodyStatic,
);
