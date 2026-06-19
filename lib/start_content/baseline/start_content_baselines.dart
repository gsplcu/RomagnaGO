import 'abbonamenti_ordinari_baseline.dart';
import 'biglietto_abbonamenti_baseline.dart';
import 'biglietto_acquista_baseline.dart';
import 'biglietto_informazioni_baseline.dart';
import 'biglietto_regolamento_baseline.dart';
import 'navetta_bussi_baseline.dart';
import 'navetta_cesenatico_baseline.dart';
import 'navetta_milano_marittima_baseline.dart';
import 'navetta_navettomare_baseline.dart';
import 'navetta_shuttlemare_baseline.dart';
import '../start_content_id.dart';

typedef StartContentBaselineFn = Map<String, dynamic> Function();

final Map<StartContentId, StartContentBaselineFn> kStartContentBaselines = {
  StartContentId.bigliettoInformazioni: baselineBigliettoInformazioni,
  StartContentId.bigliettoAcquista: baselineBigliettoAcquista,
  StartContentId.bigliettoAbbonamenti: baselineBigliettoAbbonamenti,
  StartContentId.abbonamentiOrdinari: baselineAbbonamentiOrdinari,
  StartContentId.bigliettoRegolamento: baselineBigliettoRegolamento,
  StartContentId.servizioClienti: baselineServizioClienti,
  StartContentId.navettaCesenatico: baselineNavettaCesenatico,
  StartContentId.navettaShuttlemare: baselineNavettaShuttlemare,
  StartContentId.navettaNavettomare: baselineNavettaNavettomare,
  StartContentId.navettaMilanoMarittima: baselineNavettaMilanoMarittima,
  StartContentId.navettaBussi: baselineNavettaBussi,
};

Map<String, dynamic>? baselineFor(StartContentId id) {
  final fn = kStartContentBaselines[id];
  return fn?.call();
}

/// Baseline servizio clienti — solo testi e contatti mostrati in app.
Map<String, dynamic> baselineServizioClienti() => {
  'sourceUrl': 'https://www.startromagna.it/servizio-clienti/',
  'intro':
      'Puoi parlare con Start Romagna attraverso diversi canali, '
      'scegliendo quello più adatto alle tue esigenze: telefono, WhatsApp, '
      'email, modulo online o social network.',
  'infoStartPhoneDisplay': '199.11.55.77',
  'infoStartPhoneTel': '199115577',
  'phoneIntro':
      'Numero telefonico unico per informazioni su servizi e orari del '
      'trasporto pubblico locale nei bacini di Forlì-Cesena, Ravenna e Rimini.',
  'phoneBullets': [
    'Informazioni su linee, orari, percorsi, titoli di viaggio e assistenza generale.',
    'Tariffa massima 0,1188 € al minuto + IVA da ogni telefono fisso.',
  ],
  'phoneCaption':
      'Il costo effettivo della chiamata può variare in base al tuo operatore. '
      'Verifica sempre le condizioni della tua offerta.',
  'whatsAppDisplay': '331.65.66.555',
  'servizioClientiEmail': 'servizioclienti@startromagna.it',
  'digitalIntro':
      'Canali digitali per richiedere informazioni, inviare reclami o '
      'segnalazioni senza dover telefonare.',
  'digitalBullets': [
    'WhatsApp — 331.65.66.555: informazioni su linee, orari e percorsi. Attivo h24, 7 giorni su 7; nelle ore di chiusura del servizio clienti risponde Guido, il chatbot di Start Romagna.',
    'Email — servizioclienti@startromagna.it',
    'Reclami — per reclami o segnalazioni utilizza il modulo online dedicato.',
  ],
  'socialIntro':
      'Segui Start Romagna sui social per aggiornamenti, novità di servizio '
      'e contenuti informativi.',
  'chatbotParagraphs': [
    'Quando il Servizio Clienti non è presidiato dagli operatori, il numero '
        'WhatsApp viene gestito da Guido, il chatbot che ti aiuta a trovare '
        'rapidamente informazioni su linee, orari e percorsi.',
    'Puoi scrivere a Guido in qualsiasi momento. Nelle fasce di apertura del '
        'servizio clienti potrai essere preso in carico da un operatore se la tua '
        'richiesta richiede un supporto dedicato.',
  ],
  'telegramIntro':
      'Iscrivendoti ai canali Telegram puoi ricevere aggiornamenti in tempo reale '
      'su deviazioni, modifiche temporanee di percorso e altre informazioni di '
      'servizio nel bacino che ti interessa.',
};
