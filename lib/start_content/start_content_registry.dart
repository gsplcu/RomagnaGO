import 'start_content_id.dart';
import 'start_content_parser.dart';
import 'parsers/biglietto_informazioni_parser.dart';
import 'parsers/servizio_clienti_parser.dart';
import 'parsers/navetta_cesenatico_parser.dart';
import 'parsers/navetta_bussi_parser.dart';
import 'parsers/pass_through_baseline_parser.dart';

/// Registry parser per pacchetto. I parser assenti usano solo manifest remoto.
final Map<StartContentId, StartContentParser> kStartContentParsers = {
  StartContentId.bigliettoInformazioni: BigliettoInformazioniParser(),
  StartContentId.servizioClienti: ServizioClientiParser(),
  StartContentId.navettaCesenatico: NavettaCesenaticoParser(),
  StartContentId.navettaBussi: NavettaBussiParser(),
  StartContentId.bigliettoAcquista: PassThroughBaselineParser(
    StartContentId.bigliettoAcquista,
  ),
  StartContentId.bigliettoAbbonamenti: PassThroughBaselineParser(
    StartContentId.bigliettoAbbonamenti,
  ),
  StartContentId.abbonamentiOrdinari: PassThroughBaselineParser(
    StartContentId.abbonamentiOrdinari,
  ),
  StartContentId.bigliettoRegolamento: PassThroughBaselineParser(
    StartContentId.bigliettoRegolamento,
  ),
  StartContentId.navettaShuttlemare: PassThroughBaselineParser(
    StartContentId.navettaShuttlemare,
  ),
  StartContentId.navettaNavettomare: PassThroughBaselineParser(
    StartContentId.navettaNavettomare,
  ),
  StartContentId.navettaMilanoMarittima: PassThroughBaselineParser(
    StartContentId.navettaMilanoMarittima,
  ),
};

StartContentParser? startContentParserFor(StartContentId id) =>
    kStartContentParsers[id];
