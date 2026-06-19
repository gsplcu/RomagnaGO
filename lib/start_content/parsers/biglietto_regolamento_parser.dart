import 'package:html/parser.dart' show parse;

import '../start_content_id.dart';
import '../start_content_parser.dart';
import 'start_content_fetch.dart';
import 'start_content_page_extract.dart';

class BigliettoRegolamentoParser implements StartContentParser {
  @override
  StartContentId get id => StartContentId.bigliettoRegolamento;

  @override
  Future<Map<String, dynamic>?> fetchFromWeb() async {
    final html = await startContentDownloadPage(id.sourceUrl);
    if (html == null) return null;

    final doc = parse(html);
    final root = startContentSrRoot(doc, '.sr-regole-viaggio');
    if (root == null) return null;

    final patch = <String, dynamic>{};

    final titoliIntro = startContentSectionFirstParagraph(
      doc,
      'titoli-di-viaggio',
    );
    if (titoliIntro != null) patch['titoliIntro'] = titoliIntro;

    final titoliBullets = startContentSectionBullets(doc, 'titoli-di-viaggio');
    if (titoliBullets.isNotEmpty) patch['titoliBullets'] = titoliBullets;

    final qrIntro = startContentSectionParagraphContaining(
      doc,
      'titoli-di-viaggio',
      'validazione del biglietto',
    );
    if (qrIntro != null) patch['qrIntro'] = qrIntro;

    final qrBullets = startContentParagraphsAfter(
      doc,
      'titoli-di-viaggio',
      'validazione del biglietto',
      max: 3,
    );
    if (qrBullets.isNotEmpty) patch['qrBullets'] = qrBullets;

    final bigliettazioneBullets = startContentSectionBullets(
      doc,
      'regole-bigliettazione',
    );
    if (bigliettazioneBullets.isNotEmpty) {
      patch['bigliettazioneBullets'] = bigliettazioneBullets;
    }

    final regolamentoIntro = startContentSectionFirstParagraph(
      doc,
      'regolamento-di-viaggio',
    );
    if (regolamentoIntro != null) patch['regolamentoIntro'] = regolamentoIntro;

    final sciopero = startContentScioperoCards(root);
    if (sciopero.isNotEmpty) patch['sciopero'] = sciopero;

    final reclamiIntro = startContentSectionFirstParagraph(doc, 'reclami');
    if (reclamiIntro != null) patch['reclamiIntro'] = reclamiIntro;

    final sanzioniIntro = startContentSectionFirstParagraph(doc, 'sanzioni');
    if (sanzioniIntro != null) patch['sanzioniIntro'] = sanzioniIntro;

    final pdfUrls = startContentPdfUrlsByPatterns(root, {
      'regolamentoViaggio': RegExp(r'Regolamento-di-viaggio', caseSensitive: false),
      'sintesiRegolamento': RegExp(r'Sintesi-norme', caseSensitive: false),
      'biciMonopattino': RegExp(r'bicicletta-e-monopattino', caseSensitive: false),
      'sanzioni': RegExp(r'NORMATIVA-SANZIONI', caseSensitive: false),
      'sanzioniRules': RegExp(r'Sanzioni-Amministrative', caseSensitive: false),
      'moduloReclamo': RegExp(r'Modulo_reclamo_ART', caseSensitive: false),
    });
    if (pdfUrls.isNotEmpty) patch['pdfUrls'] = pdfUrls;

    if (patch.isEmpty) return null;
    return patch;
  }

  @override
  String? validate(Map<String, dynamic> json) {
    if ((json['titoliIntro'] as String?)?.isNotEmpty != true) {
      return 'titoliIntro';
    }
    return null;
  }
}
