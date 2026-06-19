import 'start_content_id.dart';
import 'start_content_parser.dart';
import 'parsers/biglietto_informazioni_parser.dart';
import 'parsers/servizio_clienti_parser.dart';
import 'parsers/navetta_cesenatico_parser.dart';
import 'parsers/navetta_bussi_parser.dart';
import 'parsers/biglietto_acquista_parser.dart';
import 'parsers/biglietto_abbonamenti_parser.dart';
import 'parsers/abbonamenti_ordinari_parser.dart';
import 'parsers/biglietto_regolamento_parser.dart';
import 'parsers/navetta_shuttlemare_parser.dart';
import 'parsers/navetta_navettomare_parser.dart';
import 'parsers/navetta_milano_marittima_parser.dart';

/// Registry parser per pacchetto. I parser assenti usano solo manifest remoto.
final Map<StartContentId, StartContentParser> kStartContentParsers = {
  StartContentId.bigliettoInformazioni: BigliettoInformazioniParser(),
  StartContentId.servizioClienti: ServizioClientiParser(),
  StartContentId.navettaCesenatico: NavettaCesenaticoParser(),
  StartContentId.navettaBussi: NavettaBussiParser(),
  StartContentId.bigliettoAcquista: BigliettoAcquistaParser(),
  StartContentId.bigliettoAbbonamenti: BigliettoAbbonamentiParser(),
  StartContentId.abbonamentiOrdinari: AbbonamentiOrdinariParser(),
  StartContentId.bigliettoRegolamento: BigliettoRegolamentoParser(),
  StartContentId.navettaShuttlemare: NavettaShuttlemareParser(),
  StartContentId.navettaNavettomare: NavettaNavettomareParser(),
  StartContentId.navettaMilanoMarittima: NavettaMilanoMarittimaParser(),
};

StartContentParser? startContentParserFor(StartContentId id) =>
    kStartContentParsers[id];
