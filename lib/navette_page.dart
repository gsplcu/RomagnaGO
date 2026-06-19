import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'navette_bussi_data.dart';
import 'navette_bussi_page.dart';
import 'navette_cesenatico_data.dart';
import 'navette_cesenatico_page.dart';
import 'navette_milano_marittima_page.dart';
import 'navette_navettomare_data.dart';
import 'navette_navettomare_page.dart';
import 'navette_shuttlemare_data.dart';
import 'navette_shuttlemare_page.dart';
import 'romagna_brand.dart';

class NavettePage extends StatelessWidget {
  const NavettePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Navette',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          Material(
            color: Colors.white,
            child: romagnaMenuInkRow(
              icon: Icons.sailing,
              iconColor: NavettaCesenaticoColors.green,
              title: 'Navetta Cesenatico',
              subtitle: 'Parcheggio scambiatore via Mazzini',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NavettaCesenaticoPage(),
                  ),
                );
              },
            ),
          ),
          Material(
            color: Colors.white,
            child: romagnaMenuInkRow(
              icon: Icons.airport_shuttle_rounded,
              iconColor: ShuttlemareColors.accent,
              title: 'Shuttlemare',
              subtitle: 'Trasporto a chiamata · Rimini',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NavetteShuttlemarePage(),
                  ),
                );
              },
            ),
          ),
          Material(
            color: Colors.white,
            child: romagnaMenuInkRow(
              icon: Icons.beach_access_rounded,
              iconColor: NavettoMareColors.accent,
              title: 'Navetto Mare',
              subtitle: 'Linee 65 e 66 · Ravenna',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NavettoMarePage(),
                  ),
                );
              },
            ),
          ),
          Material(
            color: Colors.white,
            child: romagnaMenuInkRow(
              icon: Icons.park_rounded,
              iconColor: NavettaCesenaticoColors.green,
              title: 'Navetta gratuita Milano Marittima',
              subtitle: 'Centro Congressi – Rotonda Corelli',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NavettaMilanoMarittimaPage(),
                  ),
                );
              },
            ),
          ),
          Material(
            color: Colors.white,
            child: romagnaMenuInkRow(
              icon: Icons.hail_rounded,
              iconColor: BusSiColors.accent,
              title: 'BusSì',
              subtitle: 'Trasporto a chiamata · Cesena',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NavetteBusSiPage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
