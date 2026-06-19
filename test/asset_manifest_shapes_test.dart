import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AssetManifest elenca GPX sotto assets/shapes', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final keys = manifest.listAssets();
    final linee = keys.where((k) => k.contains('linee.json')).toList();
    final shapes = keys.where((k) => k.startsWith('assets/shapes/')).toList();
    // ignore: avoid_print
    print('manifest count=${keys.length} linee=$linee shapes=${shapes.length} sample=${keys.take(8).toList()}');
    final ce01 = keys.where((k) => k.contains('route_CE01') && k.endsWith('.gpx')).toList();
    expect(
      shapes,
      isNotEmpty,
      reason: 'Nessun asset sotto assets/shapes/ nel manifest: '
          'verifica pubspec.yaml e fai flutter clean + rebuild.',
    );
    expect(
      ce01,
      isNotEmpty,
      reason: 'Nessun .gpx per route_CE01 nel manifest.',
    );
  });
}
