// Etichette linea/bacino in UI vs chiavi GTFS (`FC|route_id`).



import 'linee_percorsi.dart';

import 'transiti_at_stop.dart';



bool _areaIsForli(String area) => area.toLowerCase().contains('forl');



bool _areaIsCesena(String area) => area.toLowerCase() == 'cesena';



bool _routeHasCo(String routeId) => routeId.toUpperCase().contains('CO');



/// Bacino cartella asset Open Data (orari/shapes): provincia FC → sempre `FC`.

String openDataAssetBacino(RomagnaLineaRow row) {

  final b = row.bacino.toUpperCase();

  if (b == 'RA' || b == 'RN') return b;

  return 'FC';

}



/// Chiave schedule/transiti (`FC|FO13`, `RN|4`, …).

String scheduleCompositeKey(RomagnaLineaRow row) =>

    '${openDataAssetBacino(row)}|${row.routeId}';



/// Bacino mostrato in bubble e «Linee e percorsi» (da [linee.json] + regola CO su route_id).

String displayBasinUpper(RomagnaLineaRow row) {

  if (_routeHasCo(row.routeId)) return 'CO';

  final b = row.bacino.toUpperCase();

  if (b == 'CE' || b == 'FO' || b == 'CO' || b == 'RA' || b == 'RN') return b;

  if (_areaIsForli(row.area)) return 'FO';

  if (_areaIsCesena(row.area)) return 'CE';

  return b.isEmpty ? 'FC' : b;

}



/// Etichetta linea in UI (da catalogo [linee.json], già normalizzata).

String displayLineaLabel(RomagnaLineaRow row) => row.linea;



Map<String, RomagnaLineaRow> buildLineeByComposite(List<RomagnaLineaRow> rows) {

  final m = <String, RomagnaLineaRow>{};

  for (final r in rows) {

    m[scheduleCompositeKey(r)] = r;

  }

  return m;

}



StopTransitLineBubble bubbleFromLineRow(

  RomagnaLineaRow row, {

  List<String>? scheduleRouteKeys,

}) {

  return StopTransitLineBubble(

    lineaLabel: displayLineaLabel(row),

    bacinoUpper: displayBasinUpper(row),

    isExtraurban: row.area == kRomagnaExtraurbanAreaLabel,

    scheduleRouteKeys: scheduleRouteKeys ?? [scheduleCompositeKey(row)],

  );

}



String bubbleDisplaySignature(StopTransitLineBubble bubble) =>

    '${bubble.lineaLabel.trim()}|${bubble.bacinoUpper.trim().toUpperCase()}';


