/// Dati BusSì senza dipendenze Flutter (baseline + sync).
library;

Map<String, dynamic> baselineNavettaBussi() => {
  'sourceUrl': 'https://www.startromagna.it/bussi/',
  'assistenzaIntro':
      'Per informazioni relativamente a BusSì o assistenza dedicata si può contattare Start Romagna:',
  'assistenzaEmail': 'bussi@startromagna.it',
  'assistenzaPhone': '800 213480',
  'assistenzaPhoneHours':
      'Attivo nei giorni feriali: 8:00–19:00 dal lunedì al venerdì, 8:00–14:00 il sabato.',
  'summerPeriodLabel': 'Servizio BusSì dal 7 giugno al 14 settembre',
  'summerMorning': '8:30–12:30',
  'summerAfternoon': '14:30–19:30',
  'howItWorksIntro': 'BusSì prevede due opzioni per utilizzare il servizio:',
  'travelModes': [
    {
      'title': '«Viaggia Ora»',
      'body':
          'Il cliente richiede la prima corsa disponibile per raggiungere la propria destinazione.',
    },
    {
      'title': '«Pianifica Viaggio»',
      'body': 'Prenotazione per un viaggio da effettuare successivamente.',
    },
  ],
  'howItWorksFooter':
      'In entrambi i casi, l\'applicazione propone all\'utente una soluzione di viaggio in base ai veicoli disponibili. L\'utente ha 30 secondi per valutare, ed eventualmente accettare, la soluzione proposta.',
  'viaggiaOraBullets': [
    'la fermata di salita',
    'la fermata di discesa',
    'il percorso del veicolo',
    'il tempo di attesa stimato',
    'il tempo per raggiungere a piedi la fermata di salita',
    'il tempo di viaggio stimato',
    'il tempo di arrivo previsto alla destinazione finale',
  ],
  'viaggiaOraFooter':
      'Le fermate abilitate al servizio sono contrassegnate da apposita segnaletica BusSì e rilevate digitalmente sull\'applicazione MyStart. Dal 15 settembre 2023 BusSì Area Ovest consente la prenotazione anche per 22 fermate nell\'area di Bertinoro.',
  'pianificaViaggioBody':
      'Per richieste «su prenotazione», all\'utente viene indicato in arancione l\'orario di partenza possibile, quanto più prossimo all\'ora di partenza richiesta. Ad esempio, se un utente ha richiesto di poter partire alle 9:00 ma per quell\'orario non ci sono corse disponibili, l\'applicazione lo informa del fatto che la prima «partenza possibile» sarebbe alle 9:15.',
};
