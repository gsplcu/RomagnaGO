import 'package:flutter/material.dart';

import '../linee_percorsi.dart';
import '../romagna_brand.dart';

/// Arancione — linee urbane.
const Color kPercorsoLineUrbana = Color(0xFFFF9800);

/// Azzurro — litorale RA e urbane Cesenatico.
const Color kPercorsoLineLitorale = Color(0xFF29B6F6);

/// Verde — linee suburbane.
const Color kPercorsoLineSuburbana = Color(0xFF4CAF50);

/// Blu scuro — linee extraurbane.
const Color kPercorsoLineExtraurbana = Color(0xFF1E3A5F);

/// Giallo — linee scolastiche FC.
const Color kPercorsoLineScolastica = Color(0xFFF9A825);

const Color kPercorsoLineUnknown = Colors.grey;

enum _LineTipoPercorso {
  urbana,
  litoraleMarittima,
  suburbana,
  extraurbana,
  scolastica,
  metromare,
}

/// Colore condiviso per bubble, tracciato mappa e icona bus in Percorso.
Color legLineColor(String? routeKey, Map<String, RomagnaLineaRow> catalog) {
  if (routeKey == null || routeKey.isEmpty) return kPercorsoLineUnknown;

  final row = catalog[routeKey];
  final bacino = (row?.bacino ?? routeKey.split('|').first).toUpperCase();
  final linea = row?.linea ?? '';
  final area = row?.area ?? '';

  if (_isMetromare(linea, routeKey)) return kMetromareRedDark;

  final tipo = _classify(bacino: bacino, linea: linea, area: area);
  return switch (tipo) {
    _LineTipoPercorso.metromare => kMetromareRedDark,
    _LineTipoPercorso.urbana => kPercorsoLineUrbana,
    _LineTipoPercorso.litoraleMarittima => kPercorsoLineLitorale,
    _LineTipoPercorso.suburbana => kPercorsoLineSuburbana,
    _LineTipoPercorso.extraurbana => kPercorsoLineExtraurbana,
    _LineTipoPercorso.scolastica => kPercorsoLineScolastica,
  };
}

bool _isMetromare(String linea, String routeKey) {
  final l = linea.toLowerCase();
  if (l.contains('metromare')) return true;
  return routeKey.toLowerCase().contains('metromare');
}

_LineTipoPercorso _classify({
  required String bacino,
  required String linea,
  required String area,
}) {
  if (bacino == 'FC') return _classifyFc(linea: linea, area: area);
  if (bacino == 'RA') return _classifyRa(linea: linea, area: area);
  if (bacino == 'RN') return _classifyRn(linea: linea, area: area);
  return _LineTipoPercorso.extraurbana;
}

_LineTipoPercorso _classifyFc({required String linea, required String area}) {
  // Numeri di linea dalla tabella utente hanno priorità sul campo area del catalogo.
  if (_lineInSet(linea, _fcScolastiche)) return _LineTipoPercorso.scolastica;
  if (_lineInSet(linea, _fcSuburbane)) return _LineTipoPercorso.suburbana;
  if (area == 'Cesenatico' || _lineInSet(linea, _fcUrbaneCesenatico)) {
    return _LineTipoPercorso.litoraleMarittima;
  }
  if (_lineInSet(linea, _fcUrbaneForli) || _lineInSet(linea, _fcUrbaneCesena)) {
    return _LineTipoPercorso.urbana;
  }
  if (area == 'Extraurbano') return _LineTipoPercorso.extraurbana;
  if (area == 'Suburbano') return _LineTipoPercorso.suburbana;
  if (area == 'Forlì' || area == 'Cesena') return _LineTipoPercorso.urbana;
  return _LineTipoPercorso.extraurbana;
}

_LineTipoPercorso _classifyRa({required String linea, required String area}) {
  if (area == 'Extraurbano') return _LineTipoPercorso.extraurbana;

  if (_lineInSet(linea, _raLitorale)) return _LineTipoPercorso.litoraleMarittima;
  if (_lineInSet(linea, _raUrbane)) return _LineTipoPercorso.urbana;

  // Ravenna: tutto il resto (es. 140–283) = extraurbane.
  return _LineTipoPercorso.extraurbana;
}

_LineTipoPercorso _classifyRn({required String linea, required String area}) {
  if (_lineInSet(linea, _rnSuburbane)) return _LineTipoPercorso.suburbana;
  if (_lineInSet(linea, _rnUrbane)) return _LineTipoPercorso.urbana;
  return _LineTipoPercorso.extraurbana;
}

bool _lineInSet(String linea, Set<String> allowed) {
  final n = _normalizeLinea(linea);
  if (allowed.contains(n)) return true;
  if (n.contains('/')) {
    for (final part in n.split('/')) {
      if (part.isNotEmpty && allowed.contains(part)) return true;
    }
  }
  return false;
}

String _normalizeLinea(String linea) {
  return linea.trim().toUpperCase().replaceAll(' ', '');
}

// --- RA (tabella utente) ---
const _raUrbane = {
  '1', '2', '3', '4', '5', '8', '18', '30',
  '51', '52', '53', '55', '56', '59',
};
const _raLitorale = {'70', '75', '80', '90'};

// --- RN ---
const _rnUrbane = {
  '1', '2', '3', '4', '5', '7', '8', '9', '10', '11',
  '14', '15', '16', '17', '18', '19', '20',
  '27', '28', '29', '30', '43', '55', '58', '61',
};
const _rnSuburbane = {'90', '91', '92', '94', '95'};

// --- FC ---
const _fcUrbaneForli = {
  '1A', '2', '3', '4', '5', '5A', '6', '7', '8', '11', '12', '13',
};
const _fcUrbaneCesena = {
  '1', '1A', '3', '4', '5', '6', '11', '11A', '12', '13',
  '21', '31', '33', '34', '35', '41', '93',
};
const _fcUrbaneCesenatico = {'1', '2', '3'};
const _fcSuburbane = {
  '91', '92', '94', '94A', '95', '96', '96A',
};
const _fcScolastiche = {'S1', 'S2', 'S4', 'S8'};
