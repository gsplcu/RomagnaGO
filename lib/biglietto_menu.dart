// Menù «Biglietto» (home, pill in alto a dx) e sezioni segnaposto.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'biglietto_abbonamenti_page.dart';
import 'biglietto_acquista_page.dart';
import 'biglietto_regolamento_sanzioni_page.dart';
import 'biglietto_informazioni_page.dart';
import 'romagna_brand.dart';
import 'verifica_biglietto_qr_page.dart';
import 'trova_biglietto_zona_page.dart';

class _BigliettoMenuEntry {
  const _BigliettoMenuEntry({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;
}

/// Elenco voci: ogni tap apre una schermata sezione dedicata (ancora vuota).
class BigliettoMenuPage extends StatelessWidget {
  const BigliettoMenuPage({super.key});

  static const List<_BigliettoMenuEntry> _entries = [
    _BigliettoMenuEntry(title: 'Trova biglietto', icon: Icons.search_rounded),
    _BigliettoMenuEntry(
      title: 'Acquista biglietto',
      icon: Icons.shopping_cart_outlined,
    ),
    _BigliettoMenuEntry(
      title: 'Abbonamenti',
      icon: Icons.card_membership_outlined,
    ),
    _BigliettoMenuEntry(
      title: 'Verifica il tuo biglietto QR code',
      icon: Icons.qr_code_scanner_rounded,
    ),
    _BigliettoMenuEntry(
      title: 'Informazioni generali',
      icon: Icons.info_outline_rounded,
    ),
    _BigliettoMenuEntry(
      title: 'Regolamento e sanzioni',
      icon: Icons.gavel_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Biglietto',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFFAFAFA),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        itemCount: _entries.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 72,
          color: kRomagnaDarkGray.withValues(alpha: 0.08),
        ),
        itemBuilder: (context, i) {
          final e = _entries[i];
          return Material(
            color: Colors.white,
            child: InkWell(
              onTap: () {
                if (i == 0) {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const TrovaBigliettoZonaPage(),
                    ),
                  );
                  return;
                }
                if (i == 1) {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const BigliettoAcquistaPage(),
                    ),
                  );
                  return;
                }
                if (i == 2) {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const BigliettoAbbonamentiPage(),
                    ),
                  );
                  return;
                }
                if (i == 3) {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const VerificaBigliettoQrPage(),
                    ),
                  );
                  return;
                }
                if (i == 4) {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const BigliettoInformazioniPage(),
                    ),
                  );
                  return;
                }
                if (i == 5) {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const BigliettoRegolamentoSanzioniPage(),
                    ),
                  );
                  return;
                }
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder:
                        (_) => BigliettoSectionPage(
                          title: e.title,
                          icon: e.icon,
                        ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      e.icon,
                      size: 26,
                      color: kRomagnaPrimary.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        e.title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: kRomagnaDarkGray,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: kRomagnaDarkGray.withValues(alpha: 0.35),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Sezione singola: titolo in app bar; corpo vuoto (da popolare in seguito).
class BigliettoSectionPage extends StatelessWidget {
  const BigliettoSectionPage({
    super.key,
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFFAFAFA),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 48,
                color: kRomagnaPrimary.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 16),
              Text(
                'Contenuto in arrivo.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: kRomagnaDarkGray.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
