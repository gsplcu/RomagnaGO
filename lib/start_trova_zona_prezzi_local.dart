// Tariffe Trova Zona quando l’API non è raggiungibile (es. CORS su Flutter Web).

import 'start_trova_zona_api.dart';

/// Costruisce la tabella prezzi come sul sito, da numero di zone attraversate.
TrovaZonaPrezziResult buildTrovaZonaPrezziLocal(int zoneAttraversate) {
  final z = zoneAttraversate.clamp(1, 9);
  final rows = <TrovaZonaPrezzoRow>[
    TrovaZonaPrezzoRow(
      descrizione: 'Biglietto $z ${z == 1 ? 'zona' : 'zone'}',
      validita: _validitaCorsaSemplice(z),
      prezzo: _prezzoCorsaSemplice(z),
      infoUrl: Uri.parse('https://www.startromagna.it/ticket-qr-code/'),
    ),
    TrovaZonaPrezzoRow(
      descrizione: 'SmartPass 1 giorno',
      validita: '24 ore',
      prezzo: '€ 9,50',
      infoUrl: Uri.parse('https://www.startromagna.it/romagna-smartpass/'),
    ),
    TrovaZonaPrezzoRow(
      descrizione: 'SmartPass 3 giorni',
      validita: '72 ore',
      prezzo: '€ 15,00',
      infoUrl: Uri.parse('https://www.startromagna.it/romagna-smartpass/'),
    ),
    TrovaZonaPrezzoRow(
      descrizione: 'SmartPass 7 giorni',
      validita: '168 ore',
      prezzo: '€ 30,00',
      infoUrl: Uri.parse('https://www.startromagna.it/romagna-smartpass/'),
    ),
    if (z <= 8)
      TrovaZonaPrezzoRow(
        descrizione: 'Mensile $z ${z == 1 ? 'zona' : 'zone'}',
        validita: 'mensile',
        prezzo: _prezzoMensile(z),
        infoUrl: Uri.parse('https://www.startromagna.it/abbonamenti/abbonamenti-2/'),
      ),
  ];
  return TrovaZonaPrezziResult(zoneAttraversate: z, righe: rows);
}

String _validitaCorsaSemplice(int z) => switch (z) {
  1 => '60 min',
  2 => '75 min',
  3 => '90 min',
  4 => '105 min',
  5 => '135 min',
  6 => '150 min',
  7 => '165 min',
  8 => '180 min',
  _ => '195 min',
};

String _prezzoCorsaSemplice(int z) => switch (z) {
  1 => '€ 2,00',
  2 => '€ 3,00',
  3 => '€ 4,00',
  4 => '€ 5,00',
  5 => '€ 5,50',
  6 => '€ 6,00',
  7 => '€ 6,50',
  8 => '€ 7,00',
  _ => '€ 8,00',
};

String _prezzoMensile(int z) => switch (z) {
  1 => '€ 38,00',
  2 => '€ 52,00',
  3 => '€ 58,00',
  4 => '€ 60,00',
  5 => '€ 65,00',
  6 => '€ 68,00',
  7 => '€ 70,00',
  _ => '€ 75,00',
};
