/// Baseline testi Shuttlemare mostrati in app.
Map<String, dynamic> baselineNavettaShuttlemare() => {
  'sourceUrl': 'https://www.startromagna.it/shuttlemare-2026/',
  'onboardIntro':
      'Minibus fino a 18 passeggeri, riconoscibili dal logo Shuttlemare.',
  'onboardRuleGroups': [
    {
      'title': 'Accessibilità e comfort',
      'bullets': [
        'Mezzi accessibili in sedia a rotelle selezionando l\'opzione in fase di prenotazione.',
        'Il passeggino deve essere chiuso e caricato nel bagagliaio.',
        'È necessario prenotare anche per il bambino.',
      ],
    },
    {
      'title': 'Animali e condizioni di viaggio',
      'bullets': [
        'Non è consentito trasportare animali, neppure di piccola taglia.',
        'Fanno eccezione i cani guida per non vedenti.',
        'Segui sempre le indicazioni fornite in app e dal personale di servizio.',
      ],
    },
  ],
  'bookingSteps': [
    'Scarica l\'app My Start Romagna',
    'Scegli il punto di partenza e la destinazione (zona arancione ↔ zona azzurra)',
    'Seleziona il numero di passeggeri (max 5) e conferma',
    'Raggiungi la fermata del bus indicata nell\'app',
    'Sali su Shuttlemare e segui il mezzo sulla mappa',
  ],
  'parkingLots': [
    {'name': 'Ponte di Tiberio', 'address': 'Viale Tiberio, 47921 Rimini RN'},
    {
      'name': 'Caduti di Marzabotto',
      'address': 'Via Caduti di Marzabotto 36, 47921 Rimini RN',
    },
    {
      'name': 'Settebello',
      'address': 'Via Roma 70, 47921 Rimini RN',
      'unavailable': true,
    },
    {
      'name': 'Fantoni',
      'address': 'Via Giovanni Fantoni, 47921 Rimini RN',
    },
    {'name': 'Sindacati', 'address': 'Via Staccoli, 47921 Rimini RN'},
    {
      'name': 'Clementini',
      'address': 'Largo Martiri d\'Ungheria, 47921 Rimini RN',
    },
    {'name': 'Chiabrera', 'address': 'Via Chiabrera, 47921 Rimini RN'},
    {
      'name': 'Palacongressi',
      'address': 'Via della Fiera 23, 47923 Rimini RN',
    },
  ],
  'helpLinks': [
    {'title': 'Telefono', 'subtitle': '0541 300999'},
    {'title': 'Email', 'subtitle': 'shuttlemare@startromagna.it'},
    {'title': 'Servizio Clienti', 'subtitle': 'Vai ai contatti'},
  ],
};
