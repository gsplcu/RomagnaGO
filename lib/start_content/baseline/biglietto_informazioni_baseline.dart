/// Baseline «Informazioni generali» — solo campi mostrati in app.
Map<String, dynamic> baselineBigliettoInformazioni() => {
  'sourceUrl': 'https://www.startromagna.it/ticket-qr-code/',
  'zoneIntro': [
    'Il territorio regionale è suddiviso in zone: la tariffa dipende '
        'dal numero di zone attraversate tra partenza e destinazione.',
    'Le paline di fermata indicano la zona; puoi verificarla anche '
        'nella card fermata sulla mappa.',
  ],
  'corsaSempliceIntro':
      'Consentono di viaggiare anche con più mezzi nell’ambito del '
      'numero di zone riportato sul titolo. Devono essere convalidati '
      'appena saliti sul bus nell’apposito validatore.',
  'corsaSemplice': _fareRows([
    ['Biglietto 1 zona', '€ 2,00', '60 min'],
    ['Biglietto 2 zone', '€ 3,00', '75 min'],
    ['Biglietto 3 zone', '€ 4,00', '90 min'],
    ['Biglietto 4 zone', '€ 5,00', '105 min'],
    ['Biglietto 5 zone', '€ 5,50', '135 min'],
    ['Biglietto 6 zone', '€ 6,00', '150 min'],
    ['Biglietto 7 zone', '€ 6,50', '165 min'],
    ['Biglietto 8 zone', '€ 7,00', '180 min'],
    ['Biglietto 9 zone', '€ 8,00', '195 min'],
  ]),
  'multicorsaIntro':
      'Il titolo multicorsa comprende 10 ticket ed è disponibile da 1 a 5 '
      'zone. Ogni ticket ha la validità temporale prevista per la zona scelta.',
  'multicorsa': _fareRows([
    ['Multicorsa 1 zona (10 ticket)', '€ 18,00', '60 min'],
    ['Multicorsa 2 zone (10 ticket)', '€ 27,00', '75 min'],
    ['Multicorsa 3 zone (10 ticket)', '€ 36,00', '90 min'],
    ['Multicorsa 4 zone (10 ticket)', '€ 40,00', '105 min'],
    ['Multicorsa 5 zone (10 ticket)', '€ 42,00', '135 min'],
  ]),
  'multicorsaSteps': [
    {
      'number': 1,
      'title': 'Se viaggi in più persone',
      'bullets': [
        'Premi il tasto con il simbolo della persona sulla validatrice verde.',
        'Avvicina il QR Code della multicorsa al lettore luminoso.',
        'Seleziona il numero di passeggeri e conferma.',
      ],
    },
    {
      'number': 2,
      'title': 'Se viaggi da solo',
      'bullets': [
        'Segui la stessa procedura scegliendo 1 passeggero e conferma; oppure',
        'avvicina direttamente il biglietto al lettore verde per la convalida automatica.',
      ],
    },
  ],
  'dayTicketIntro': [
    'Novità Rimini: disponibile anche il Day Ticket 1 zona. Il Day Ticket '
        '1 zona è valido 24 ore e consente di muoversi nella zona scelta. '
        'Per viaggi oltre 3 zone, acquistare SmartPass 1 giorno.',
    'I Day Ticket restano disponibili solo per 1, 2 e 3 zone. Sono validi '
        '24 ore dal momento della convalida nell’ambito del numero di zone '
        'riportato sul titolo.',
  ],
  'dayTicket': _fareRows([
    ['Day Ticket 1 zona', '€ 5,00', '24 ore'],
    ['Day Ticket 2 zone', '€ 7,50', '24 ore'],
    ['Day Ticket 3 zone', '€ 8,50', '24 ore'],
  ]),
  'dayTicketNote':
      'Dal 4° livello zonale in poi non sono previsti Day Ticket: '
      'acquistare SmartPass 1 giorno.',
  'metromareIntro':
      'Valido per l’intera tratta Rimini–Riccione, nell’area urbana di '
      'Rimini e nella zona Riccione/Misano.',
  'metromare': _fareRows([
    ['Metromare 75 min.', '€ 3,00', '75 min'],
    ['Metromare 24 ore', '€ 5,00', '24 ore'],
  ]),
  'metromarePurchase':
      'Acquisto: biglietterie Start Romagna, rivendite lungo la tratta, '
      'punti vendita nel libretto orari e app dedicate.',
  'aBordoIntro':
      'Per l’acquisto a bordo sono previste tariffe dedicate. Il biglietto '
      'rilasciato è valido per il numero di zone acquistato e per la '
      'relativa validità temporale.',
  'aBordo': _fareRows([
    ['Biglietto 1 zona', '€ 3,00', '60 min'],
    ['Biglietto 2 zone', '€ 4,00', '75 min'],
    ['Biglietto 3 zone', '€ 5,00', '90 min'],
    ['Biglietto 4 zone', '€ 6,00', '105 min'],
    ['Biglietto 5 zone', '€ 7,00', '135 min'],
  ]),
  'smartPass': {
    'title': 'Romagna SmartPass',
    'description':
        'Copre Rimini, Forlì-Cesena e Ravenna. Disponibili titoli da '
        '1 giorno (€ 9,50), 3 giorni (€ 15,00) e 7 giorni (€ 30,00).',
  },
  'railSmartPass': {
    'title': 'Rail SmartPass',
    'description':
        'Bus illimitato Start Romagna + treni regionali su tratte selezionate. '
        '3 giorni: € 35,00 · 7 giorni: € 70,00. Bambini 0–4 anni gratis con adulto.',
  },
  'qrValidation':
      'Per controllare zona, scadenza e corse rimanenti: tasto informativo '
      'sulla validatrice verde, poi avvicina il QR. Non serve tenere il '
      'biglietto sotto il lettore mentre leggi il display.',
  'faq': [
    {
      'question': 'Come verifico se la multicorsa è stata convalidata?',
      'answer':
          'Tasto informativo sulla validatrice, avvicina il titolo: '
          'vedrai zona, scadenza, corse rimanenti e passeggeri timbrati.',
    },
    {
      'question': 'Posso controllare il biglietto prima di salire?',
      'answer':
          'Sì, puoi verificarlo con lo scanner in app oppure con il tasto '
          'informativo a bordo.',
    },
  ],
  'footerNote':
      'Dati ufficiali dal sito startromagna.it. Per il titolo adatto '
      'al tuo viaggio puoi usare anche «Trova biglietto» in app.',
};

List<Map<String, String>> _fareRows(List<List<String>> rows) => [
  for (final r in rows)
    {'ticket': r[0], 'price': r[1], 'validity': r[2]},
];
