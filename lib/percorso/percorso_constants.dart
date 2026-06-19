/// Parametri planner Percorso v1.
abstract final class PercorsoConstants {
  // Regola 2 (walk progressiva): avvicinamento/uscita ≤ 1000 m,
  // interscambio intermedio generico ≤ 300 m. Allineati a
  // RouteEvaluator.standard (singola fonte di verità delle regole).
  static const double maxAccessWalkMeters = 1000;
  static const double maxDirectWalkMeters = 5000;
  static const double walkDetourFactor = 1.28;
  static const double walkSpeedMps = 4500 / 3600; // 4,5 km/h
  static const double maxTransferWalkMeters = 300;
  /// Cambio a piedi tra fermate hub (es. Carpinello → Forlì Punto Bus, Sagittario → San Mauro).
  static const double maxHubTransferWalkMeters = 2800;
  /// Hub Forlì: distanza reale tra capolinee periferici e Punto Bus.
  static const double maxForliHubTransferWalkMeters = 7000;
  /// Cesenatico / San Mauro: collegamento verso linee RN (es. 2CO → 4 RN).
  static const double maxCesenaticoHubTransferWalkMeters = 4000;
  static const double busSlowerThanWalkRatio = 1.05;

  static const int minTransferWaitMinutes = 4;

  /// Raggio OTP-like per unire fermate nella stessa StopArea (metri).
  static const double stopAreaClusterRadiusMeters = 60;

  /// Penalità fissa (minuti) per ogni cambio mezzo (boarding stress), oltre al
  /// cammino e al minimum_transfer_time GTFS. Usata nel grafo trasferimenti.
  static const int boardingTransferPenaltyMinutes = 2;

  /// Raggio massimo per precomputare archi nel [TransferGraphIndex] (metri).
  static const double maxTransferGraphBuildRadiusMeters = 7000;
  static const int maxStopCandidatesPerEnd = 8;
  static const int maxStopCandidatesAddressEnd = 8;

  /// Per indirizzi: cerca fermate su linee dell’altro capo entro questo raggio.
  static const double routeEnrichRadiusMeters = 6500;
  static const int maxRoutesEnrichedPerEnd = 16;
  static const int maxPlannerCandidates = 220;
  static const int maxItinerariesReturned = 3;
  static const int maxTransitResultsReserved = 1;

  /// Resta in bus fino alla fermata che riduce il tragitto a piedi verso la destinazione.
  static const double maxEgressWalkMeters = 1000;

  /// Mostra una 2ª/3ª alternativa solo se non dominata e entro questo scarto di durata.
  static const int meaningfulAlternativeMaxExtraMin = 18;

  // --- Diversificazione delle alternative (Opzione 2/3 per comfort) ---
  /// Finestra (minuti) entro cui un'alternativa di comfort può arrivare DOPO
  /// l'opzione 1 più rapida, restando comunque proponibile. Volutamente ampia.
  static const int comfortAlternativeMaxExtraMin = 35;

  /// Risparmio minimo di metri a piedi perché valga la pena proporre l'opzione
  /// "Meno strada a piedi".
  static const double diversifyMinWalkSavingMeters = 300;

  /// Risparmio minimo di attesa (minuti) per l'opzione "Più fluido".
  static const int diversifyMinWaitSavingMin = 6;

  static const int suggestTrainWhenTransfersAtLeast = 4;

  /// Oltre questa distanza in linea d’aria si salta la ricerca TPL (troppo lenta/inutile).
  /// Oltre ~25 km in linea d’aria si salta la ricerca TPL (es. Ravenna–Rimini).
  /// Sotto questa soglia restano tratte interurbane bus (es. Cesenatico–Cesena ~18 km).
  static const double longHaulSkipTransitMeters = 80000;

  /// Oltre questa distanza, se il TPL trova risultati, aggiungi hint "valuta il treno".
  static const double trainHintThresholdMeters = 25000;
  /// Ricerca su giorni adiacenti se il giorno richiesto non ha servizio.
  static const int maxAdjacentDaySearch = 7;

  // --- RAPTOR round-based search ---
  static const int maxRaptorRounds = 4;
  static const int maxTripsPerMarkedStop = 16;
  static const int maxMarkedStopsPerRound = 1200;
  static const int ldMaxRaptorRounds = 4;
  static const int ldMaxTripsPerMarkedStop = 10;
  static const int ldMaxMarkedStopsPerRound = 300;
  static const int ldMaxAdjacentDaySearch = 2;
  static const int searchBudgetMs = 8000;

  /// Penalità score (minuti) se la corsa parte molto dopo l’orario richiesto.
  static const int lateDepartureScorePenaltyMin = 12;

  static const int scoreTransferPenaltyFastMin = 20;
  static const int scoreTransferPenaltyFewChangesMin = 25;
  static const double scoreWalkWeightFast = 0.35;
  static const double scoreWalkWeightMinWalk = 2.2;
  static const int prenotazionePenaltyFastMin = 6;
}
