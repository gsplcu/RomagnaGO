/// Baseline «Regolamento e sanzioni».
Map<String, dynamic> baselineBigliettoRegolamento() => {
  'sourceUrl':
      'https://www.startromagna.it/biglietti/regolamenti-sanzioni-regole-di-viaggio/',
  'pdfUrls': {
    'regolamentoViaggio':
        'https://www.startromagna.it/wp-content/uploads/2025/05/Regolamento-di-viaggio-Start-Romagna_5.5.25.pdf',
    'sintesiRegolamento':
        'https://www.startromagna.it/wp-content/uploads/2025/02/Sintesi-norme-di-viaggio_bus_nov22.pdf',
    'biciMonopattino':
        'https://www.startromagna.it/wp-content/uploads/2022/11/Regolamento-bicicletta-e-monopattino-pieghevoli.pdf',
    'sanzioni':
        'https://www.startromagna.it/wp-content/uploads/2026/02/NORMATIVA-SANZIONI-AMMINISTRATIVE-2025.pdf',
    'sanzioniRules':
        'https://www.startromagna.it/wp-content/uploads/2023/11/Sanzioni-Amministrative.pdf',
    'moduloReclamo':
        'https://www.startromagna.it/downloads/Modulo_reclamo_ART.pdf',
  },
  'titoliIntro':
      'Per accedere al servizio occorre munirsi di regolare titolo di '
      'viaggio e provvedere alla sua convalida appena saliti a bordo.',
  'titoliBullets': [
    'Acquisto presso punti vendita autorizzati e emettitrici automatiche.',
    'Acquisto a bordo con sistema EMV StarTap, dove disponibile.',
    'Acquisto dalle emettitrici di bordo con eventuale sovrapprezzo.',
    'Acquisto da smartphone tramite app dedicate o canali WhatsApp disponibili.',
  ],
  'qrIntro':
      'La validazione del biglietto avviene esponendo il lato con il '
      'QR Code al lettore ottico posto sotto il validatore verde. '
      'Un messaggio sul display e un segnale acustico confermano la convalida.',
  'qrBullets': [
    'Sul display puoi verificare lo stato del biglietto premendo il tasto "i".',
    'I titoli acquistati dalle emettitrici di bordo non necessitano di convalida.',
    'In caso di errore di timbratura avvisa subito il conducente.',
  ],
  'bigliettazioneBullets': [
    'Sali dalla porta anteriore e mostra il titolo di viaggio al conducente.',
    'Convalida appena salito a bordo e segnala subito eventuali guasti del validatore.',
    'I titoli devono essere integri, riconoscibili e non alterati.',
  ],
  'regolamentoIntro':
      'Il Regolamento di viaggio Start Romagna contiene le norme che '
      'regolano diritti e doveri dei passeggeri nei bacini di '
      'Forlì-Cesena, Ravenna e Rimini.',
  'sciopero': [
    {
      'title': 'Forlì-Cesena',
      'lines': ['Fasce garantite: 5:30–8:30', 'Fasce garantite: 13:00–16:00'],
    },
    {
      'title': 'Ravenna',
      'lines': [
        'Servizio minimo complessivo di 6 ore.',
        'Fasce: 5:30–8:30 e 12:00–15:00.',
        'Garantiti i servizi riservati fuori fascia.',
      ],
    },
    {
      'title': 'Rimini',
      'lines': [
        'Corse escluse dagli scioperi: 6:00–9:00 e 13:00–16:00.',
        'Garantiti anche i servizi per studenti dell’obbligo.',
        'Le corse avviate entro 30 minuti dall’inizio dello sciopero proseguono fino al capolinea.',
      ],
    },
  ],
  'reclamiIntro':
      'I clienti Start Romagna possono inviare segnalazioni e reclami '
      'tramite i canali dedicati del Customer Care. Per i casi previsti '
      'dalla normativa europea è disponibile anche il modulo di reclamo '
      'ART.',
  'sanzioniIntro':
      'Qui trovi le sanzioni in vigore per i viaggiatori sprovvisti di '
      'regolare titolo di viaggio e la normativa di riferimento. Se vuoi '
      'presentare ricorso, puoi usare la pagina dedicata di Start Romagna.',
  'helpIntro':
      'Per dubbi su regole, reclami o sanzioni puoi contattare il Servizio Clienti.',
};
