import 'package:flutter_test/flutter_test.dart';
import 'package:RomagnaGO/start_content/baseline/biglietto_informazioni_baseline.dart';
import 'package:RomagnaGO/start_content/parsers/abbonamenti_web_extract.dart';
import 'package:RomagnaGO/start_content/parsers/biglietto_informazioni_parser.dart';
import 'package:RomagnaGO/start_content/parsers/start_content_page_extract.dart';
import 'package:RomagnaGO/start_content/start_content_hash.dart';

void main() {
  test('biglietto informazioni baseline validates', () {
    final json = baselineBigliettoInformazioni();
    final parser = BigliettoInformazioniParser();
    expect(parser.validate(json), isNull);
    expect(startContentPayloadHash(json), isNotEmpty);
    final rows = json['corsaSemplice'] as List;
    expect(rows.length, greaterThanOrEqualTo(9));
  });

  test('i18n map keeps first italian occurrence', () {
    const html = """
      hero_subtitle: 'Prima versione italiana',
      hero_subtitle: 'English version',
      monthly_p1: 'Testo mensile',
    """;
    final map = startContentItalianI18nMap(html);
    expect(map['hero_subtitle'], 'Prima versione italiana');
    expect(map['monthly_p1'], 'Testo mensile');
  });

  test('normalize prezzo formats euro', () {
    expect(startContentNormalizePrezzo('38,00 €'), '€ 38,00');
    expect(startContentNormalizePrezzo('€ 256,00'), '€ 256,00');
  });

  test('subscription table parser reads rows', () {
    const html = '''
      <table>
        <tr><th>Abbonamento</th><th>Prezzo</th></tr>
        <tr><td>Mensile 1 zona</td><td>38,00 €</td></tr>
        <tr><td>Mensile 2 zone</td><td>52,00 €</td></tr>
      </table>
    ''';
    final tables = startContentParseSubscriptionTables(html);
    expect(tables.length, 1);
    expect(tables.first.first['titolo'], 'Mensile 1 zona');
    expect(tables.first.first['prezzo'], '€ 38,00');
  });

  test('abbonamenti patch from fixture html', () {
    const html = '''
      hero_subtitle: 'Gli abbonamenti sono caricati su tessera Mi Muovo.',
      hero_badge_1: 'Mensili e annuali',
      hero_badge_2: 'Più zone',
      monthly_p1: 'Intro mensili.',
      monthly_li1: 'regola uno',
      monthly_li2: 'regola due',
      yearly_p1: 'Intro annuali.',
      yearly_li1: 'validità uno',
      yearly_li2: 'validità due',
      yearly_p3: 'Nota validità.',
      forli_monthly_title: 'Forlì mensili',
      forli_monthly_p: 'Testo Forlì.',
      cesena_monthly_title: 'Cesena mensili',
      cesena_monthly_p: 'Testo Cesena.',
      job_monthly_title: 'Job Ticket',
      job_monthly_p: 'Testo job.',
      forli_yearly_title: 'Forlì annuali',
      forli_yearly_p: 'Testo Forlì ann.',
      cesena_yearly_title: 'Cesena annuali',
      cesena_yearly_p: 'Testo Cesena ann.',
      job_yearly_title: 'Job annuale',
      job_yearly_p: 'Testo job ann.',
      mobility_title: 'Mobility',
      mobility_p1: 'Mobility uno.',
      mobility_p2: 'Mobility due.',
      over70_title: 'Over 70',
      over70_p1: 'Over uno.',
      over70_p2: 'Over due.',
      <table><tr><td>M1</td><td>10,00 €</td></tr></table>
      <table><tr><td>F1</td><td>11,00 €</td></tr></table>
      <table><tr><td>C1</td><td>12,00 €</td></tr></table>
      <table><tr><td>J1</td><td>13,00 €</td></tr></table>
      <table><tr><td>A1</td><td>20,00 €</td></tr></table>
      <table><tr><td>AF1</td><td>21,00 €</td></tr></table>
      <table><tr><td>AC1</td><td>22,00 €</td></tr></table>
      <table><tr><td>AJ1</td><td>23,00 €</td></tr></table>
      <table><tr><td>Mob1</td><td>24,00 €</td></tr></table>
      <table><tr><td>O1</td><td>25,00 €</td></tr></table>
    ''';
    final ordinari = parseAbbonamentiOrdinariPatch(html);
    expect(ordinari, isNotNull);
    expect(ordinari!['mensili'], isA<Map>());
    expect(ordinari['annuali'], isA<Map>());

    final overview = parseBigliettoAbbonamentiPatch(html);
    expect(overview, isNotNull);
    expect(overview!['overviewIntro'], contains('Mi Muovo'));
  });
}
