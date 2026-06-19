import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:RomagnaGO/photon_romagna.dart';

void main() {
  test('Photon search URI returns hits for Varthema', () async {
    final uri = Uri.https('photon.komoot.io', '/api/', <String, String>{
      'q': 'via Ludovico de varthema',
      'lat': kRomagnaPhotonCenterLat,
      'lon': kRomagnaPhotonCenterLon,
      'bbox': kRomagnaPhotonBbox,
      'limit': '12',
    });
    final response = await http.get(uri, headers: kPhotonHttpHeaders);
    expect(response.statusCode, 200, reason: response.body);

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final features = decoded['features'] as List<dynamic>;
    expect(features, isNotEmpty);

    final hits = await searchRomagnaAddresses('via Ludovico de varthema');
    expect(hits, isNotEmpty, reason: 'searchRomagnaAddresses empty');
    expect(isWithinRomagnaBounds(hits.first.point), isTrue);
  });
}
