import 'package:flutter_test/flutter_test.dart';
import 'package:RomagnaGO/infobus_realtime.dart';

void main() {
  group('infobusSiteLineMatchesBubbleLine', () {
    test('exact and case', () {
      expect(infobusSiteLineMatchesBubbleLine('94', '94'), isTrue);
      expect(infobusSiteLineMatchesBubbleLine('METROMARE', 'Metromare'), isTrue);
    });

    test('leading zeros', () {
      expect(infobusSiteLineMatchesBubbleLine('04', '4'), isTrue);
      expect(infobusSiteLineMatchesBubbleLine('4', '04'), isTrue);
    });

    test('Cesenatico linee 1 e 4 CO distinte', () {
      expect(infobusSiteLineMatchesBubbleLine('1', '1'), isTrue);
      expect(infobusSiteLineMatchesBubbleLine('4', '4'), isTrue);
      expect(infobusSiteLineMatchesBubbleLine('1', '4'), isFalse);
      expect(infobusSiteLineMatchesBubbleLine('4', '1'), isFalse);
      expect(infobusSiteLineMatchesBubbleLine('1CO', '1'), isTrue);
    });

    test('S094 vs 94', () {
      expect(infobusSiteLineMatchesBubbleLine('S094', '94'), isTrue);
      expect(infobusSiteLineMatchesBubbleLine('s091', '91'), isTrue);
    });

    test('SA96 vs 96A / 96', () {
      expect(infobusSiteLineMatchesBubbleLine('SA96', '96A'), isTrue);
      expect(infobusSiteLineMatchesBubbleLine('SA96', '96'), isTrue);
    });

    test('CE01 vs 1', () {
      expect(infobusSiteLineMatchesBubbleLine('CE01', '1'), isTrue);
    });

    test('1CO vs 1', () {
      expect(infobusSiteLineMatchesBubbleLine('1CO', '1'), isTrue);
    });

    test('slash variants', () {
      expect(infobusSiteLineMatchesBubbleLine('94', '94/94A'), isTrue);
      expect(infobusSiteLineMatchesBubbleLine('94/94A', '94'), isTrue);
    });

    test('no false prefix', () {
      expect(infobusSiteLineMatchesBubbleLine('10', '1'), isFalse);
      expect(infobusSiteLineMatchesBubbleLine('13', '1'), isFalse);
    });
  });
}
