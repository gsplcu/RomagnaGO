import 'prezzo_row_baseline.dart';

/// Baseline tabelle abbonamenti ordinari (mensili e annuali).
Map<String, dynamic> baselineAbbonamentiOrdinari() => {
  'sourceUrl': 'https://www.startromagna.it/abbonamenti/abbonamenti-2/',
  'mensili': _mensili(),
  'annuali': _annuali(),
};

Map<String, dynamic> _mensili() => {
  'intro':
      'Gli abbonamenti mensili sono personali e consentono di viaggiare con più '
      'mezzi nell’ambito delle zone prescelte. Sono validi dal primo all’ultimo '
      'giorno del mese (1 mese solare) e vengono caricati su tessera Mi Muovo.',
  'ricaricaBullets': [
    'Dal 1° al 21° giorno del mese: validità dal 1° all’ultimo giorno del mese in corso',
    'Dal 22° all’ultimo giorno del mese: validità dal 1° all’ultimo giorno del mese successivo',
  ],
  'tariffarioGenerale': pr([
    ['Mensile 1 zona', '€ 38,00'],
    ['Mensile 2 zone', '€ 52,00'],
    ['Mensile 3 zone', '€ 58,00'],
    ['Mensile 4 zone', '€ 60,00'],
    ['Mensile 5 zone', '€ 65,00'],
    ['Mensile 6 zone', '€ 68,00'],
    ['Mensile 7 zone', '€ 70,00'],
    ['Mensile 8 zone', '€ 75,00'],
  ]),
  'forli': {
    'title': 'Forlì (zona 860)',
    'intro':
        'Abbonamenti mensili personali (1 mese solare) nella zona 860 di Forlì a tariffa scontata.',
    'rows': pr([
      ['Personale', '€ 31,00'],
      ['Università', '€ 24,00', 'Studenti universitari'],
      [
        'Senior',
        '€ 24,00',
        'Pensionati e non occupati oltre 65 anni, residenti a Forlì',
      ],
      ['Job Ticket', '€ 24,00', 'Chi lavora nel territorio comunale di Forlì'],
      [
        'Job Ticket Dipendenti Comunali',
        '€ 17,00',
        'Dipendenti del Comune di Forlì',
      ],
    ]),
  },
  'cesena': {
    'title': 'Cesena (zone 880 + 881 Borello)',
    'intro':
        'Abbonamenti mensili personali (1 mese solare) nella zona 880 Cesena e 881 Borello.',
    'rows': pr([
      ['Personale', '€ 38,00'],
      ['Università (titolo 8883)', '—', 'Vedi nota sotto'],
      [
        'Senior',
        '€ 28,00',
        'Pensionati e non occupati oltre 65 anni, residenti a Cesena',
      ],
      [
        'Job Ticket',
        '€ 12,00',
        'Insegnanti scuole statali di Cesena e dipendenti Comune, Unione Valle del Savio, ASP, biblioteca',
      ],
    ]),
    'note':
        'Dal 01/01/2026 è disponibile il titolo 8883 – Abbonamento Mensile '
        'Università Cesena, al costo di € 18,00, valido nel blocco Cesena '
        '(zone 880 + 881 Borello).',
  },
  'jobTicketCesena': {
    'title': 'Abbonamento mensile Job Ticket',
    'intro':
        'Riservato agli insegnanti di scuole pubbliche statali con sede a Cesena e ai '
        'dipendenti di: Comune di Cesena, Unione Valle del Savio, ASP Cesena, '
        'biblioteca comunale di Cesena.',
    'rows': pr([
      ['Job Ticket mensile 1 zona', '€ 12,00'],
      ['Job Ticket mensile 2 zone', '€ 26,00'],
      ['Job Ticket mensile 3 zone', '€ 32,00'],
      ['Job Ticket mensile 4 zone', '€ 34,00'],
      ['Job Ticket mensile 5 zone', '€ 39,00'],
      ['Job Ticket mensile 6 zone', '€ 42,00'],
      ['Job Ticket mensile 7 zone', '€ 44,00'],
    ]),
  },
};

Map<String, dynamic> _annuali() => {
  'intro':
      'Gli abbonamenti annuali sono personali e consentono di viaggiare con più '
      'mezzi nell’ambito delle zone prescelte. Vengono caricati elettronicamente '
      'su tessera Mi Muovo da parte delle biglietterie Start Romagna.',
  'validitaBullets': [
    'Dal 1° al 21° giorno del mese: validi dal 1° giorno del mese in corso',
    'Dal 22° all’ultimo giorno del mese: validi dal 1° giorno del mese successivo',
  ],
  'validitaNota':
      'Durata in mesi solari: 12 mesi = fino alla fine dell’11° mese successivo '
      'a quello di inizio validità.',
  'tariffarioGenerale': pr([
    ['Annuale 1 zona', '€ 256,00'],
    ['Annuale 2 zone', '€ 329,00'],
    ['Annuale 3 zone', '€ 413,00'],
    ['Annuale 4 zone', '€ 465,00'],
    ['Annuale 5 zone', '€ 512,00'],
    ['Annuale 6 zone', '€ 554,00'],
    ['Annuale 7 zone', '€ 596,00'],
  ]),
  'forli': {
    'title': 'Forlì (zona 860)',
    'intro':
        'Abbonamenti annuali personali (12 mesi solari) nella zona 860 di Forlì.',
    'rows': pr([
      ['Personale', '€ 200,00'],
      [
        'Università',
        'Variabile',
        'Integrato da Comune di Forlì e UniBO; prezzo in base a ISEE e contributi',
      ],
      [
        'Scolastico per classi',
        '€ 50,00',
        'Classe scuola dell’obbligo + 2 insegnanti, giorni scolastici, anno scolastico',
      ],
      [
        'Senior',
        '€ 150,00',
        'Pensionati e non occupati oltre 65 anni, residenti a Forlì',
      ],
      ['Job Ticket', '€ 150,00', 'Chi lavora nel territorio comunale di Forlì'],
      [
        'Job Ticket Dipendenti Comunali',
        '€ 80,00',
        'Dipendenti del Comune di Forlì',
      ],
    ]),
  },
  'cesena': {
    'title': 'Cesena (zone 880 + 881 Borello)',
    'intro':
        'Abbonamenti annuali personali (12 mesi solari) nella zona 880 Cesena e 881 Borello.',
    'rows': pr([
      ['Personale', '€ 256,00'],
      [
        'Scolastico per classi',
        '€ 50,00',
        'Classe scuola dell’obbligo + 2 insegnanti, giorni scolastici, anno scolastico',
      ],
      [
        'Senior',
        '€ 131,00',
        'Pensionati e non occupati oltre 65 anni, residenti a Cesena',
      ],
      [
        'Job Ticket',
        '€ 44,00',
        'Insegnanti scuole statali di Cesena e dipendenti Comune, Unione Valle del Savio, ASP, biblioteca',
      ],
    ]),
  },
  'jobTicketCesena': {
    'title': 'Abbonamento annuale Job Ticket',
    'intro':
        'Riservato agli insegnanti di scuole pubbliche statali con sede a Cesena e ai '
        'dipendenti di: Comune di Cesena, Unione Valle del Savio, ASP Cesena, '
        'biblioteca comunale di Cesena.',
    'rows': pr([
      ['Job Ticket annuale 1 zona', '€ 44,00'],
      ['Job Ticket annuale 2 zone', '€ 114,00'],
      ['Job Ticket annuale 3 zone', '€ 193,00'],
      ['Job Ticket annuale 4 zone', '€ 243,00'],
      ['Job Ticket annuale 5 zone', '€ 287,00'],
      ['Job Ticket annuale 6 zone', '€ 327,00'],
      ['Job Ticket annuale 7 zone', '€ 367,00'],
    ]),
  },
  'mobility': {
    'title': 'Abbonamento annuale Mobility',
    'intro':
        'Validità annuale (12 mesi solari dal 1° giorno del mese prescelto) nel '
        'percorso indicato sulla tessera. In vendita solo presso le biglietterie '
        'Start Romagna, riservato ai dipendenti di aziende convenzionate – Bacino di Ravenna.',
    'rows': pr([
      ['Mobility 1 zona', '€ 243,00'],
      ['Mobility 2 zone', '€ 313,00'],
      ['Mobility 3 zone', '€ 392,00'],
      ['Mobility 4 zone', '€ 442,00'],
      ['Mobility 5 zone', '€ 486,00'],
      ['Mobility 6 zone', '€ 526,00'],
      ['Mobility 7 zone', '€ 566,00'],
    ]),
  },
  'over70Ravenna': {
    'title': 'Abbonamento annuale Over 70 – Ravenna',
    'intro':
        'Riservato a chi ha compiuto 70 anni alla data di avvio validità e risiede '
        'nel Comune o nella Provincia di Ravenna. Consente di viaggiare sull’intera '
        'rete del bacino di Ravenna (12 mesi solari dal 1° giorno del mese prescelto).',
    'rows': pr([
      [
        'Over 70 intero bacino – Residenti Comune di Ravenna',
        '€ 256,00 (€ 77,00*)',
      ],
      [
        'Over 70 intero bacino – Residenti Provincia di Ravenna',
        '€ 156,00',
      ],
    ]),
    'note':
        '* I residenti nel Comune di Ravenna possono beneficiare del rimborso '
        'idrocarburi (70% del costo): costo reale € 77,00.',
  },
};
