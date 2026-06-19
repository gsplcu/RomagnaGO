/// Regole di business per la frontiera di Pareto del motore RAPTOR.
///
/// `RouteEvaluator` centralizza in un unico punto le tre regole tassative del
/// routing, così che la funzione di costo, i limiti di cammino e il filtro
/// delle soluzioni dominanti restino coerenti e testabili in isolamento:
///
///  1. **Costo Pareto-ottimale** — penalità fissa per ogni cambio, così le
///     linee dirette vincono su quelle frammentate anche se un po' più lente.
///  2. **Restrizione walk progressiva** — limiti distinti per il cammino di
///     avvicinamento/uscita (accesso/egress) e per gli interscambi intermedi.
///  3. **Massimizzazione di bordo** — a parità di orario di arrivo, scarta le
///     soluzioni che anticipano la discesa a piedi e preferisce quella che
///     tiene l'utente sul mezzo fino alla fermata più vicina al target.
///
/// È volutamente disaccoppiato dai modelli del planner: opera su primitivi
/// (minuti, metri, conteggi) per essere riutilizzabile e unit-testabile.
class RouteEvaluator {
  const RouteEvaluator({
    this.transferPenalty = const Duration(minutes: 15),
    this.boardingTransferPenalty = const Duration(minutes: 2),
    this.maxAccessEgressWalkMeters = 1000,
    this.maxIntermediateTransferWalkMeters = 300,
    this.walkMetersPerMinute = 75,
    this.walkWeight = 0.35,
    this.arrivalTieBreakSeconds = 60,
    this.boardMaximizationWalkMeters = 150,
  });

  /// Configurazione standard usata dal planner.
  static const RouteEvaluator standard = RouteEvaluator();

  // --- Regola 1: funzione di costo ---
  /// Penalità temporale equivalente per ciascun cambio (transfer_count).
  final Duration transferPenalty;

  /// Penalità aggiunta su ogni arco pedonale di interscambio dopo una corsa
  /// tra due [StopArea] diverse (simula attesa/boarding al cambio mezzo).
  /// Distinta da [transferPenalty], che serve solo al ranking Pareto.
  final Duration boardingTransferPenalty;

  // --- Regola 2: limiti di cammino ---
  /// Cammino massimo di avvicinamento iniziale e di uscita finale.
  final double maxAccessEgressWalkMeters;

  /// Cammino massimo per un interscambio intermedio tra due fermate.
  final double maxIntermediateTransferWalkMeters;

  // --- Parametri funzione di costo ---
  final double walkMetersPerMinute;
  final double walkWeight;

  // --- Regola 3: massimizzazione di bordo ---
  /// Tolleranza entro cui due arrivi sono considerati "pari".
  final int arrivalTieBreakSeconds;

  /// Riduzione di cammino minima per giustificare una discesa anticipata.
  final double boardMaximizationWalkMeters;

  /// Regola 1 — costo scalare (in minuti-equivalenti) per il ranking di Pareto.
  ///
  /// `extraPenaltyMin` raccoglie penalità contestuali (prenotazione, partenza
  /// tardiva, attese lunghe) calcolate dal chiamante.
  double cost({
    required Duration travelTime,
    required double walkMeters,
    required int transferCount,
    double extraPenaltyMin = 0,
  }) {
    final timeMin = travelTime.inSeconds / 60.0;
    final walkMin = (walkMeters / walkMetersPerMinute) * walkWeight;
    final transferMin = transferCount * transferPenalty.inMinutes;
    return timeMin + walkMin + transferMin + extraPenaltyMin;
  }

  /// Penalità (minuti) imputabile ai soli cambi: utile dove il costo base è
  /// già calcolato altrove e va solo iniettata la Regola 1.
  double transferPenaltyMinutes(int transferCount) =>
      transferCount * transferPenalty.inMinutes.toDouble();

  /// Regola 2 — cammino di accesso/egress ammesso.
  bool accessEgressWalkAllowed(double meters) =>
      meters <= maxAccessEgressWalkMeters;

  /// Regola 2 — cammino di interscambio intermedio ammesso.
  bool intermediateTransferWalkAllowed(double meters) =>
      meters <= maxIntermediateTransferWalkMeters;

  /// Due ORARI DI ARRIVO ASSOLUTI sono "pari" entro la tolleranza di tie-break.
  ///
  /// IMPORTANTE (Punto E): i parametri devono essere l'orario di arrivo reale
  /// dell'itinerario (epoch secondi di `legs.last.end`), NON la durata totale.
  /// Due itinerari con stessa durata ma partenze diverse arrivano in momenti
  /// diversi: confrontare la durata creava finti pareggi e applicava la
  /// massimizzazione di bordo a soluzioni che non arrivano affatto insieme.
  bool arrivalsAreTied(int arriveEpochSecA, int arriveEpochSecB) =>
      (arriveEpochSecA - arriveEpochSecB).abs() <= arrivalTieBreakSeconds;

  /// Regola 3 — vero se [candidate] è dominata da [incumbent] per
  /// massimizzazione di bordo: stesso arrivo (entro tolleranza) ma [candidate]
  /// fa scendere prima e camminare sensibilmente di più verso il target.
  bool dominatedByBoardMaximization({
    required int candidateArriveSec,
    required double candidateEgressWalkMeters,
    required int incumbentArriveSec,
    required double incumbentEgressWalkMeters,
  }) {
    if (!arrivalsAreTied(candidateArriveSec, incumbentArriveSec)) return false;
    return candidateEgressWalkMeters >
        incumbentEgressWalkMeters + boardMaximizationWalkMeters;
  }
}
