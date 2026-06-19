import 'package:flutter_test/flutter_test.dart';
import 'package:RomagnaGO/infobus_realtime.dart';
import 'package:RomagnaGO/romagna_brand.dart';

InfobusLineCatalog _testCatalog() {
  return InfobusLineCatalog(const [
    InfobusCatalogLine(
      linea: '1',
      bacino: 'FC',
      area: 'Cesena',
      routeId: 'CE01',
    ),
    InfobusCatalogLine(
      linea: '1A',
      bacino: 'FC',
      area: 'Cesena',
      routeId: 'CEA1',
    ),
    InfobusCatalogLine(
      linea: '1',
      bacino: 'FC',
      area: 'Cesenatico',
      routeId: '1CO',
    ),
    InfobusCatalogLine(
      linea: '2',
      bacino: 'FC',
      area: 'Cesenatico',
      routeId: '2CO',
    ),
    InfobusCatalogLine(
      linea: '1A',
      bacino: 'FC',
      area: 'Forlì',
      routeId: 'FOA1',
    ),
    InfobusCatalogLine(
      linea: '94/94A',
      bacino: 'FC',
      area: 'Suburbano',
      routeId: 'S094',
    ),
    InfobusCatalogLine(
      linea: '1',
      bacino: 'RA',
      area: 'Ravenna',
      routeId: '1',
    ),
    InfobusCatalogLine(
      linea: '94',
      bacino: 'RN',
      area: 'Rimini',
      routeId: '94',
    ),
  ]);
}

void main() {
  group('infobusLineeInteressateTokens', () {
    test('keeps slash variants intact', () {
      expect(
        infobusLineeInteressateTokens('94/94A · 112 · 126'),
        ['94/94A', '112', '126'],
      );
    });
  });

  group('infobusLineeInteressateParsed', () {
    test('parses locality suffix from display string', () {
      final tokens = infobusLineeInteressateParsed('1 CO · 94/94A FC');
      expect(tokens.length, 2);
      expect(tokens[0].lineLabel, '1');
      expect(tokens[0].siteLocality, 'CO');
      expect(tokens[1].lineLabel, '94/94A');
      expect(tokens[1].siteLocality, 'FC');
    });
  });

  group('infobusAvvisoMatchesRouteId', () {
    final catalog = _testCatalog();

    test('matches 94/94A FC avviso when filter and bacino align', () {
      expect(
        infobusAvvisoMatchesRouteId(
          lineTokens: const [
            InfobusSiteLineToken(lineLabel: '94/94A', siteLocality: 'FC'),
          ],
          avvisoLocalityHint: 'CO',
          avvisoBasins: {'FC'},
          requiredBasin: 'FC',
          filterRouteId: 'S094',
          catalog: catalog,
        ),
        isTrue,
      );
    });

    test('isolates FC 94/94A from Rimini line 94 via bacino', () {
      expect(
        infobusAvvisoMatchesRouteId(
          lineTokens: const [InfobusSiteLineToken(lineLabel: '94')],
          avvisoLocalityHint: null,
          avvisoBasins: {'RN'},
          requiredBasin: 'FC',
          filterRouteId: 'S094',
          catalog: catalog,
        ),
        isFalse,
      );
    });

    test('Cesena 1 does not match Cesenatico tokens with CO suffix', () {
      expect(
        infobusAvvisoMatchesRouteId(
          lineTokens: const [
            InfobusSiteLineToken(lineLabel: '1', siteLocality: 'CO'),
            InfobusSiteLineToken(lineLabel: '2', siteLocality: 'CO'),
          ],
          avvisoLocalityHint: 'CO',
          avvisoBasins: {'FC'},
          requiredBasin: 'FC',
          filterRouteId: 'CE01',
          catalog: catalog,
        ),
        isFalse,
      );
    });

    test('Cesenatico 1 matches with CO suffix', () {
      expect(
        infobusAvvisoMatchesRouteId(
          lineTokens: const [
            InfobusSiteLineToken(lineLabel: '1', siteLocality: 'CO'),
          ],
          avvisoLocalityHint: 'CO',
          avvisoBasins: {'FC'},
          requiredBasin: 'FC',
          filterRouteId: '1CO',
          catalog: catalog,
        ),
        isTrue,
      );
    });

    test('listing Cesenatico avviso infers CO from hint for bare 1/2/3', () {
      expect(
        infobusAvvisoMatchesRouteId(
          lineTokens: const [
            InfobusSiteLineToken(lineLabel: '1'),
            InfobusSiteLineToken(lineLabel: '2'),
          ],
          avvisoLocalityHint: 'CO',
          avvisoBasins: {'FC'},
          requiredBasin: 'FC',
          filterRouteId: '1CO',
          catalog: catalog,
        ),
        isTrue,
      );
      expect(
        infobusAvvisoMatchesRouteId(
          lineTokens: const [
            InfobusSiteLineToken(lineLabel: '1'),
            InfobusSiteLineToken(lineLabel: '2'),
          ],
          avvisoLocalityHint: 'CO',
          avvisoBasins: {'FC'},
          requiredBasin: 'FC',
          filterRouteId: 'CE01',
          catalog: catalog,
        ),
        isFalse,
      );
    });

    test('Cesena 1A does not match Cesenatico line 1', () {
      expect(
        infobusAvvisoMatchesRouteId(
          lineTokens: const [
            InfobusSiteLineToken(lineLabel: '1', siteLocality: 'CO'),
          ],
          avvisoLocalityHint: 'CO',
          avvisoBasins: {'FC'},
          requiredBasin: 'FC',
          filterRouteId: 'CEA1',
          catalog: catalog,
        ),
        isFalse,
      );
    });

    test('Cesena 1A matches CE suffix token', () {
      expect(
        infobusAvvisoMatchesRouteId(
          lineTokens: const [
            InfobusSiteLineToken(lineLabel: '1A', siteLocality: 'CE'),
          ],
          avvisoLocalityHint: 'CE',
          avvisoBasins: {'FC'},
          requiredBasin: 'FC',
          filterRouteId: 'CEA1',
          catalog: catalog,
        ),
        isTrue,
      );
    });

    test('Ravenna line 1 does not match Cesena line 1 in FC filter', () {
      expect(
        infobusAvvisoMatchesRouteId(
          lineTokens: const [InfobusSiteLineToken(lineLabel: '1')],
          avvisoLocalityHint: 'RA',
          avvisoBasins: {'RA'},
          requiredBasin: 'FC',
          filterRouteId: 'CE01',
          catalog: catalog,
        ),
        isFalse,
      );
    });

    test('avoids false positives between 1 and 10', () {
      expect(
        infobusAvvisoMatchesRouteId(
          lineTokens: const [
            InfobusSiteLineToken(lineLabel: '10'),
            InfobusSiteLineToken(lineLabel: '11'),
          ],
          avvisoLocalityHint: 'RA',
          avvisoBasins: {'RA'},
          requiredBasin: 'RA',
          filterRouteId: '1',
          catalog: catalog,
        ),
        isFalse,
      );
    });

    test('empty filter route matches any avviso in bacino', () {
      expect(
        infobusAvvisoMatchesRouteId(
          lineTokens: const [InfobusSiteLineToken(lineLabel: '125')],
          avvisoLocalityHint: null,
          avvisoBasins: {'FC'},
          requiredBasin: 'FC',
          filterRouteId: '',
          catalog: catalog,
        ),
        isTrue,
      );
    });
  });

  group('inferInfobusAvvisoLocalityHint', () {
    test('detects Cesenatico from subtitle', () {
      expect(
        inferInfobusAvvisoLocalityHint(
          'Cesenatico, Giro d\'Italia',
          'FC extraurbano ∙ Cesenatico',
        ),
        'CO',
      );
    });

    test('detects Cesena without matching Cesenatico', () {
      expect(
        inferInfobusAvvisoLocalityHint(
          'Cesena, deviazione linea 11A',
          'Cesena ∙ FC extraurbano',
        ),
        'CE',
      );
    });
  });

  group('compareRomagnaLineLabels', () {
    test('sorts slash variants by leading number', () {
      final lines = ['96A', '94/94A', '100', '92', '11/11A', 'R'];
      lines.sort(compareRomagnaLineLabels);
      expect(lines, ['11/11A', '92', '94/94A', '96A', '100', 'R']);
    });

    test('does not treat 10 as part of 1 ordering', () {
      expect(compareRomagnaLineLabels('1', '10'), lessThan(0));
      expect(compareRomagnaLineLabels('10', '1'), greaterThan(0));
    });
  });
}
