/// Quali fermate TPL mostrare sulla mappa (filtro per bacino).
enum StopVisibilityOption { all, fc, rn, ra }

String stopVisibilityLabel(StopVisibilityOption o) {
  switch (o) {
    case StopVisibilityOption.all:
      return 'Tutte le fermate';
    case StopVisibilityOption.fc:
      return 'Solo bacino di Forlì-Cesena';
    case StopVisibilityOption.rn:
      return 'Solo bacino di Rimini';
    case StopVisibilityOption.ra:
      return 'Solo bacino di Ravenna';
  }
}
