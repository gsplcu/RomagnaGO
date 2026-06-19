import 'package:html/parser.dart' show parse;

import '../start_content_html_utils.dart';
import '../start_content_id.dart';
import '../start_content_parser.dart';
import 'start_content_fetch.dart';
import 'start_content_page_extract.dart';

const _kStarTapUrl =
    'https://www.startromagna.it/biglietti/startap-sistema-emv/';
const _kAppUrl =
    'https://www.startromagna.it/biglietti/acquista-da-smartphone/';
const _kEmettitriceUrl =
    'https://www.startromagna.it/biglietti/acquista-da-emettitrice/';

class BigliettoAcquistaParser implements StartContentParser {
  @override
  StartContentId get id => StartContentId.bigliettoAcquista;

  @override
  Future<Map<String, dynamic>?> fetchFromWeb() async {
    final results = await Future.wait([
      startContentDownloadPage(id.sourceUrl),
      startContentDownloadPage(_kStarTapUrl),
      startContentDownloadPage(_kAppUrl),
      startContentDownloadPage(_kEmettitriceUrl),
    ]);

    final patch = <String, dynamic>{};
    final chatHtml = results[0];
    final starTapHtml = results[1];
    final appHtml = results[2];
    final emettHtml = results[3];

    if (chatHtml != null) {
      final whatsapp = _parseWhatsapp(chatHtml);
      if (whatsapp != null) patch['whatsapp'] = whatsapp;
    }
    if (starTapHtml != null) {
      final onboard = _parseOnboard(starTapHtml);
      if (onboard != null) patch['onboard'] = onboard;
    }
    if (appHtml != null) {
      final app = _parseApp(appHtml);
      if (app != null) patch['app'] = app;
    }
    if (emettHtml != null) {
      final emett = _parseEmettitrice(emettHtml);
      if (emett != null) patch['emettitrice'] = emett;
    }

    if (patch.isEmpty) return null;
    return patch;
  }

  Map<String, dynamic>? _parseWhatsapp(String html) {
    final doc = parse(html);
    final patch = <String, dynamic>{};

    for (final p in doc.querySelectorAll('p')) {
      final text = startContentNormalizeText(
        startContentDecodeHtmlEntities(p.text),
      );
      if (text.contains('Chat&Go') &&
          text.contains('WhatsApp') &&
          text.length > 80) {
        patch['intro'] = text;
        break;
      }
    }

    final steps = <Map<String, dynamic>>[];
    final titles = doc.querySelectorAll('.sr-chat-step-title');
    final texts = doc.querySelectorAll('.sr-chat-step-text');
    for (var i = 0; i < titles.length && i < 3; i++) {
      steps.add({
        'number': i + 1,
        'title': startContentNormalizeText(titles[i].text),
        'text': startContentNormalizeText(texts[i].text),
      });
    }
    if (steps.isNotEmpty) patch['steps'] = steps;

    final bullets = <String>[];
    for (final li in doc.querySelectorAll('.sr-chat-list li')) {
      final text = startContentNormalizeText(
        startContentDecodeHtmlEntities(li.text),
      );
      if (text.startsWith('Non devi') ||
          text.startsWith('Puoi acquistare') ||
          text.startsWith('I biglietti') ||
          text.startsWith('È possibile')) {
        bullets.add(text);
      }
    }
    if (bullets.isNotEmpty) patch['bullets'] = bullets;

    for (final p in doc.querySelectorAll('p')) {
      final text = startContentNormalizeText(
        startContentDecodeHtmlEntities(p.text),
      );
      if (text.contains('convalidare') && text.contains('QR Code')) {
        patch['note'] = text;
        break;
      }
    }

    if (patch.isEmpty) return null;
    return patch;
  }

  Map<String, dynamic>? _parseOnboard(String html) {
    final root = startContentSrRoot(parse(html), '.sr-startap');
    if (root == null) return null;

    final patch = <String, dynamic>{};
    final intro = startContentParagraphUnderHeading(root, 'Cos’è StarTap') ??
        startContentParagraphUnderHeading(root, "Cos'è StarTap");
    if (intro != null) patch['intro'] = intro;

    final prima = startContentListItemsUnderHeading(
      root,
      'Quali carte sono accettate',
    );
    if (prima.isNotEmpty) patch['primaDiSalireBullets'] = prima;

    final acquisto = startContentListItemsUnderHeading(
      root,
      'Come usare StarTap passo per passo',
    );
    if (acquisto.isNotEmpty) patch['acquistoBullets'] = acquisto;

    final noteItems = startContentListItemsUnderHeading(
      root,
      'Quanto costa viaggiare',
    );
    if (noteItems.isNotEmpty) {
      patch['note'] = noteItems.join(' ');
    }

    final fareTable = startContentParseFareTable(root);
    if (fareTable.isNotEmpty) patch['fareTable'] = fareTable;

    if (patch.isEmpty) return null;
    return patch;
  }

  Map<String, dynamic>? _parseApp(String html) {
    final root = startContentSrRoot(parse(html), '.sr-smartapp');
    if (root == null) return null;

    final patch = <String, dynamic>{};
    final intro = startContentParagraphUnderHeading(
      root,
      'Acquisto da smartphone',
    );
    if (intro != null) patch['intro'] = intro;

    final apps = <Map<String, String>>[];
    for (final li
        in startContentListItemsUnderHeading(root, 'Le app per acquistare')) {
      final parts = li.split('–');
      if (parts.length >= 2) {
        apps.add({
          'name': startContentNormalizeText(parts[0]),
          'description': startContentNormalizeText(parts.sublist(1).join('–')),
        });
      }
    }
    if (apps.isNotEmpty) patch['apps'] = apps;

    if (patch.isEmpty) return null;
    return patch;
  }

  Map<String, dynamic>? _parseEmettitrice(String html) {
    final root = startContentSrRoot(parse(html), '.sr-emettitrici');
    if (root == null) return null;

    final patch = <String, dynamic>{};
    final intro = startContentParagraphUnderHeading(
      root,
      'Biglietti e abbonamenti da emettitrici',
    );
    if (intro != null) patch['intro'] = intro;

    final terra = <String>[];
    for (final ul in root.querySelectorAll('ul[data-lang-block="it"], ul')) {
      if (ul.querySelector('[data-lang-block="en"]') != null) continue;
      for (final li in ul.querySelectorAll('li')) {
        final text = startContentNormalizeText(
          startContentDecodeHtmlEntities(li.text),
        );
        if (text.contains('zona') && text.contains('vendita')) {
          terra.add(text);
        }
      }
      if (terra.isNotEmpty) break;
    }
    if (terra.isNotEmpty) patch['terraBullets'] = terra;

    final traghetto = startContentParagraphUnderHeading(
      root,
      'Emettitrici traghetto',
    );
    if (traghetto != null) patch['traghettoBody'] = traghetto;

    final bordo = startContentListItemsUnderHeading(
      root,
      'Emettitrici di bordo',
    );
    if (bordo.isNotEmpty) patch['bordoBullets'] = bordo;

    final fareTable = startContentParseFareTable(root);
    if (fareTable.isNotEmpty) patch['fareTable'] = fareTable;

    if (patch.isEmpty) return null;
    return patch;
  }

  @override
  String? validate(Map<String, dynamic> json) {
    final whatsapp = json['whatsapp'];
    if (whatsapp is Map && (whatsapp['intro'] as String?)?.isNotEmpty == true) {
      return null;
    }
    final onboard = json['onboard'];
    if (onboard is Map && (onboard['intro'] as String?)?.isNotEmpty == true) {
      return null;
    }
    return 'sections';
  }
}
