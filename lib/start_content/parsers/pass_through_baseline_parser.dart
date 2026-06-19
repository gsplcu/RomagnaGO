import '../start_content_id.dart';
import '../start_content_parser.dart';

class PassThroughBaselineParser implements StartContentParser {
  const PassThroughBaselineParser(this.id);

  @override
  final StartContentId id;

  @override
  Future<Map<String, dynamic>?> fetchFromWeb() async => null;

  @override
  String? validate(Map<String, dynamic> json) {
    if (json.isEmpty) return 'empty';
    return null;
  }
}
