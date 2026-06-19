// Contenuto «Abbonamenti mensili personali» e «Abbonamenti annuali ordinari»
// da startromagna.it/abbonamenti/abbonamenti-2/

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'romagna_brand.dart';
import 'start_content/start_content_json.dart';

class _PrezzoRow {
  const _PrezzoRow(this.titolo, this.prezzo, {this.nota});

  final String titolo;
  final String prezzo;
  final String? nota;
}

List<_PrezzoRow> _prezzoRowsFromJson(List<Map<String, String?>> raw) => [
  for (final row in raw)
    _PrezzoRow(
      row['titolo'] ?? '',
      row['prezzo'] ?? '',
      nota: row['nota'],
    ),
];

Widget _prezzoSubsection(Map<String, dynamic>? block) {
  if (block == null) return const SizedBox.shrink();
  final rows = _prezzoRowsFromJson(scPrezzoRows(block, 'rows'));
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(scText(block, 'title'), style: _subsectionStyle()),
      const SizedBox(height: 6),
      Text(scText(block, 'intro'), style: _bodyStyle()),
      const SizedBox(height: 8),
      _PrezzoTable(rows: rows),
      if (scText(block, 'note').isNotEmpty) ...[
        const SizedBox(height: 10),
        _NoteBox(text: scText(block, 'note')),
      ],
    ],
  );
}

class AbbonamentiMensiliSection extends StatelessWidget {
  const AbbonamentiMensiliSection({super.key, required this.content});

  final Map<String, dynamic> content;

  @override
  Widget build(BuildContext context) {
    final tariffario = _prezzoRowsFromJson(
      scPrezzoRows(content, 'tariffarioGenerale'),
    );
  return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(scText(content, 'intro'), style: _bodyStyle()),
        const SizedBox(height: 10),
        Text('In fase di ricarica:', style: _labelStyle()),
        const SizedBox(height: 6),
        _BulletList(items: scStringList(content, 'ricaricaBullets')),
        const SizedBox(height: 14),
        Text('Tariffario abbonamenti mensili', style: _labelStyle()),
        const SizedBox(height: 8),
        _PrezzoTable(rows: tariffario),
        const SizedBox(height: 16),
        _prezzoSubsection(scMap(content, 'forli')),
        const SizedBox(height: 16),
        _prezzoSubsection(scMap(content, 'cesena')),
        const SizedBox(height: 16),
        _prezzoSubsection(scMap(content, 'jobTicketCesena')),
      ],
    );
  }
}

class AbbonamentiAnnualiSection extends StatelessWidget {
  const AbbonamentiAnnualiSection({super.key, required this.content});

  final Map<String, dynamic> content;

  @override
  Widget build(BuildContext context) {
    final tariffario = _prezzoRowsFromJson(
      scPrezzoRows(content, 'tariffarioGenerale'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(scText(content, 'intro'), style: _bodyStyle()),
        const SizedBox(height: 10),
        Text('Validità in base alla data di acquisto:', style: _labelStyle()),
        const SizedBox(height: 6),
        _BulletList(items: scStringList(content, 'validitaBullets')),
        const SizedBox(height: 8),
        Text(scText(content, 'validitaNota'), style: _bodyStyle()),
        const SizedBox(height: 14),
        Text('Tariffario abbonamento annuale', style: _labelStyle()),
        const SizedBox(height: 8),
        _PrezzoTable(rows: tariffario),
        const SizedBox(height: 16),
        _prezzoSubsection(scMap(content, 'forli')),
        const SizedBox(height: 16),
        _prezzoSubsection(scMap(content, 'cesena')),
        const SizedBox(height: 16),
        _prezzoSubsection(scMap(content, 'jobTicketCesena')),
        const SizedBox(height: 16),
        _prezzoSubsection(scMap(content, 'mobility')),
        const SizedBox(height: 16),
        _prezzoSubsection(scMap(content, 'over70Ravenna')),
      ],
    );
  }
}
/// Dropdown espandibile per sezioni abbonamenti ordinari.
class AbbonamentiOrdinariDropdown extends StatelessWidget {
  const AbbonamentiOrdinariDropdown({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            visualDensity: VisualDensity.compact,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            iconColor: kRomagnaPrimary,
            collapsedIconColor: kRomagnaDarkGray.withValues(alpha: 0.55),
            title: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: kRomagnaDarkGray,
              ),
            ),
            children: [child],
          ),
        ),
      ),
    );
  }
}

class _PrezzoTable extends StatelessWidget {
  const _PrezzoTable({required this.rows});

  final List<_PrezzoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kRomagnaDarkGray.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: kRomagnaPrimary.withValues(alpha: 0.08),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Abbonamento',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kRomagnaDarkGray.withValues(alpha: 0.65),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Prezzo',
                    textAlign: TextAlign.end,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kRomagnaDarkGray.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: kRomagnaDarkGray.withValues(alpha: 0.06),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          rows[i].titolo,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            height: 1.3,
                            color: kRomagnaDarkGray,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          rows[i].prezzo,
                          textAlign: TextAlign.end,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: kRomagnaDarkGray,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (rows[i].nota != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      rows[i].nota!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        height: 1.35,
                        color: kRomagnaDarkGray.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kRomagnaPrimary,
                  ),
                ),
                Expanded(
                  child: Text(item, style: _bodyStyle()),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          height: 1.4,
          color: const Color(0xFF9A3412),
        ),
      ),
    );
  }
}

TextStyle _bodyStyle() => GoogleFonts.inter(
  fontSize: 12.5,
  height: 1.42,
  color: kRomagnaDarkGray.withValues(alpha: 0.78),
);

TextStyle _labelStyle() => GoogleFonts.inter(
  fontSize: 12.5,
  fontWeight: FontWeight.w700,
  color: kRomagnaDarkGray,
);

TextStyle _subsectionStyle() => GoogleFonts.inter(
  fontSize: 13,
  fontWeight: FontWeight.w700,
  color: kRomagnaPrimary,
);
