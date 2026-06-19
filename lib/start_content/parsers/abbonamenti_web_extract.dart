import 'start_content_page_extract.dart';

Map<String, dynamic>? parseAbbonamentiOrdinariPatch(String html) {
  final i18n = startContentItalianI18nMap(html);
  final tables = startContentParseSubscriptionTables(html);
  if (tables.length < 10) return null;

  final patch = <String, dynamic>{
    'mensili': _mensiliPatch(i18n, tables),
    'annuali': _annualiPatch(i18n, tables),
  };
  return patch;
}

Map<String, dynamic> _mensiliPatch(
  Map<String, String> i18n,
  List<List<Map<String, String?>>> tables,
) {
  final m = <String, dynamic>{};
  _putPlain(m, 'intro', i18n['monthly_p1']);
  final bullets = [
    startContentI18nPlain(i18n['monthly_li1']),
    startContentI18nPlain(i18n['monthly_li2']),
  ].where((s) => s.isNotEmpty).toList();
  if (bullets.isNotEmpty) m['ricaricaBullets'] = bullets;
  m['tariffarioGenerale'] = tables[0];
  m['forli'] = {
    'title': startContentI18nPlain(i18n['forli_monthly_title']),
    'intro': startContentI18nPlain(i18n['forli_monthly_p']),
    'rows': tables[1],
  };
  m['cesena'] = {
    'title': startContentI18nPlain(i18n['cesena_monthly_title']),
    'intro': startContentI18nPlain(i18n['cesena_monthly_p']),
    'rows': tables[2],
    if (i18n['cesena_monthly_alert'] != null)
      'note': startContentI18nPlain(i18n['cesena_monthly_alert']),
  };
  m['jobTicketCesena'] = {
    'title': startContentI18nPlain(i18n['job_monthly_title']),
    'intro': startContentI18nPlain(i18n['job_monthly_p']),
    'rows': tables[3],
  };
  return m;
}

Map<String, dynamic> _annualiPatch(
  Map<String, String> i18n,
  List<List<Map<String, String?>>> tables,
) {
  final a = <String, dynamic>{};
  _putPlain(a, 'intro', i18n['yearly_p1']);
  final bullets = [
    startContentI18nPlain(i18n['yearly_li1']),
    startContentI18nPlain(i18n['yearly_li2']),
  ].where((s) => s.isNotEmpty).toList();
  if (bullets.isNotEmpty) a['validitaBullets'] = bullets;
  _putPlain(a, 'validitaNota', i18n['yearly_p3']);
  a['tariffarioGenerale'] = tables[4];
  a['forli'] = {
    'title': startContentI18nPlain(i18n['forli_yearly_title']),
    'intro': startContentI18nPlain(i18n['forli_yearly_p']),
    'rows': tables[5],
  };
  a['cesena'] = {
    'title': startContentI18nPlain(i18n['cesena_yearly_title']),
    'intro': startContentI18nPlain(i18n['cesena_yearly_p']),
    'rows': tables[6],
  };
  a['jobTicketCesena'] = {
    'title': startContentI18nPlain(i18n['job_yearly_title']),
    'intro': startContentI18nPlain(i18n['job_yearly_p']),
    'rows': tables[7],
  };
  a['mobility'] = {
    'title': startContentI18nPlain(i18n['mobility_title']),
    'intro': [
      startContentI18nPlain(i18n['mobility_p1']),
      startContentI18nPlain(i18n['mobility_p2']),
    ].where((s) => s.isNotEmpty).join(' '),
    'rows': tables[8],
  };
  a['over70Ravenna'] = {
    'title': startContentI18nPlain(i18n['over70_title']),
    'intro': [
      startContentI18nPlain(i18n['over70_p1']),
      startContentI18nPlain(i18n['over70_p2']),
    ].where((s) => s.isNotEmpty).join(' '),
    'rows': tables[9],
    if (i18n['over70_alert'] != null)
      'note': startContentI18nPlain(i18n['over70_alert']),
  };
  return a;
}

Map<String, dynamic>? parseBigliettoAbbonamentiPatch(String html) {
  final i18n = startContentItalianI18nMap(html);
  final patch = <String, dynamic>{};

  _putPlain(patch, 'overviewIntro', i18n['hero_subtitle']);
  final chips = [
    startContentI18nPlain(i18n['hero_badge_1']),
    startContentI18nPlain(i18n['hero_badge_2']),
  ].where((s) => s.isNotEmpty).toList();
  if (chips.isNotEmpty) patch['overviewChips'] = chips;

  final tessera = _tesseraBullets(i18n);
  if (tessera.isNotEmpty) patch['tesseraBullets'] = tessera;

  final zone = [
    startContentI18nPlain(i18n['zones_p1']),
    startContentI18nPlain(i18n['zones_p2']),
  ].where((s) => s.isNotEmpty).join(' ');
  if (zone.isNotEmpty) patch['zoneBody'] = zone;

  _putPlain(patch, 'ordinariBody', i18n['monthly_p1']);

  final under26 = _promoBlock(
    i18n,
    titleKey: 'u26_title',
    bodyKeys: ['u26_p1', 'u26_p2'],
    buttonKey: 'u26_btn',
    urlPattern: RegExp(r'href="([^"]*under-26[^"]*)"'),
    html: html,
  );
  if (under26 != null) patch['under26'] = under26;

  _putPlain(patch, 'rinnovoTitle', i18n['renew_title']);
  final renewBullets = [
    startContentI18nPlain(i18n['renew_li1']),
    startContentI18nPlain(i18n['renew_li2']),
    startContentI18nPlain(i18n['renew_li3']),
  ].where((s) => s.isNotEmpty).toList();
  if (renewBullets.isNotEmpty) patch['rinnovoBullets'] = renewBullets;
  _putPlain(patch, 'ricaricaButtonLabel', i18n['renew_box_1_btn']);

  final ricaricaUrl = RegExp(
    r'href="(https://www\.startromagna\.it/abbonamenti/ricarica-abbonamento/)"',
  ).firstMatch(html)?.group(1);
  if (ricaricaUrl != null) patch['ricaricaUrl'] = ricaricaUrl;

  if (patch.isEmpty) return null;
  return patch;
}

List<String> _tesseraBullets(Map<String, String> i18n) {
  final intro = startContentI18nPlain(i18n['card_intro']);
  final box = startContentI18nPlain(i18n['card_box_text']);
  final bullets = <String>[];
  if (intro.isNotEmpty) {
    final parts = intro.split(RegExp(r'\.\s+')).where((s) => s.trim().isNotEmpty);
    for (final part in parts) {
      bullets.add(part.endsWith('.') ? part : '$part.');
    }
  }
  if (box.isNotEmpty && !bullets.contains(box)) bullets.add(box);
  return bullets;
}

Map<String, dynamic>? _promoBlock(
  Map<String, String> i18n, {
  required String titleKey,
  required List<String> bodyKeys,
  required String buttonKey,
  required RegExp urlPattern,
  required String html,
}) {
  final title = startContentI18nPlain(i18n[titleKey]);
  if (title.isEmpty) return null;
  final body = bodyKeys
      .map((k) => startContentI18nPlain(i18n[k]))
      .where((s) => s.isNotEmpty)
      .join(' ');
  final buttonLabel = startContentI18nPlain(i18n[buttonKey]);
  final url = urlPattern.firstMatch(html)?.group(1);
  return {
    'title': title,
    if (body.isNotEmpty) 'body': body,
    if (buttonLabel.isNotEmpty) 'buttonLabel': buttonLabel,
    if (url != null) 'url': url,
  };
}

void _putPlain(Map<String, dynamic> map, String key, String? raw) {
  final v = startContentI18nPlain(raw);
  if (v.isNotEmpty) map[key] = v;
}
