/// Identificativi dei pacchetti contenuto Start Romagna sincronizzabili.
enum StartContentId {
  bigliettoInformazioni(
    'biglietto_informazioni',
    'https://www.startromagna.it/ticket-qr-code/',
  ),
  bigliettoAcquista(
    'biglietto_acquista',
    'https://www.startromagna.it/chat-go/',
  ),
  bigliettoAbbonamenti(
    'biglietto_abbonamenti',
    'https://www.startromagna.it/abbonamenti/abbonamenti-2/',
  ),
  abbonamentiOrdinari(
    'abbonamenti_ordinari',
    'https://www.startromagna.it/abbonamenti/abbonamenti-2/',
  ),
  bigliettoRegolamento(
    'biglietto_regolamento',
    'https://www.startromagna.it/biglietti/regolamenti-sanzioni-regole-di-viaggio/',
  ),
  servizioClienti(
    'servizio_clienti',
    'https://www.startromagna.it/servizio-clienti/',
  ),
  navettaCesenatico(
    'navetta_cesenatico',
    'https://www.startromagna.it/navetta-cesenatico/',
  ),
  navettaShuttlemare(
    'navetta_shuttlemare',
    'https://www.startromagna.it/shuttlemare-2026/',
  ),
  navettaNavettomare(
    'navetta_navettomare',
    'https://www.startromagna.it/navetto-mare-2026/',
  ),
  navettaMilanoMarittima(
    'navetta_milano_marittima',
    'https://www.startromagna.it/navetta-gratuita-milano-marittima-percorsi-e-orari-2026/',
  ),
  navettaBussi(
    'navetta_bussi',
    'https://www.startromagna.it/bussi/',
  );

  const StartContentId(this.fileKey, this.sourceUrl);

  final String fileKey;
  final String sourceUrl;

  String get bundledAsset => 'assets/data/start_content/$fileKey.json';

  static StartContentId? byFileKey(String key) {
    for (final id in values) {
      if (id.fileKey == key) return id;
    }
    return null;
  }
}
