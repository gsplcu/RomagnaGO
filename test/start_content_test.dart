import 'package:flutter_test/flutter_test.dart';
import 'package:RomagnaGO/start_content/baseline/biglietto_informazioni_baseline.dart';
import 'package:RomagnaGO/start_content/parsers/biglietto_informazioni_parser.dart';
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
}
