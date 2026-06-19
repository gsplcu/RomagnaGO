import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'avvisi_page.dart';
import 'romagna_brand.dart';
import 'servizio_clienti_page.dart';

const String kDeviazioniStartBotUrl = 'https://t.me/DeviazioniStartBot';

/// Pagina introduttiva al bot Telegram per deviazioni e avvisi Start Romagna.
/// Dalla chiusura si accede alla sezione Avvisi in app.
class AvvisiTelegramIntroPage extends StatelessWidget {
  const AvvisiTelegramIntroPage({super.key});

  void _openAvvisiInApp(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AvvisiPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const telegramAccent = Color(0xFF0088CC);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Avvisi',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  telegramAccent,
                  telegramAccent.withValues(alpha: 0.82),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: telegramAccent.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Deviazioni Start Romagna',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Bot Telegram @DeviazioniStartBot',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Consulta deviazioni e avvisi di servizio',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: kRomagnaDarkGray,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'RomagnaGO mette a disposizione un bot Telegram dedicato per '
            'controllare in modo rapido le deviazioni temporanee, le variazioni '
            'di percorso e le comunicazioni operative sulla rete di trasporto.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.45,
              color: kRomagnaDarkGray.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Dal bot puoi:\n'
            '• filtrare le informazioni per bacino e linea\n'
            '• filtrare solo gli avvisi attivi in questo momento\n'
            '• cercare gli avvisi attivi in un determinato periodo\n'
            'Trovare subito gli aggiornamenti che ti interessano è ancora più facile. '
            'È un canale complementare agli avvisi che trovi qui in app.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.45,
              color: kRomagnaDarkGray.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () => openStartRomagnaUrl(kDeviazioniStartBotUrl),
            icon: const Icon(Icons.open_in_new_rounded, size: 20),
            label: Text(
              'Apri bot su Telegram',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: telegramAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _openAvvisiInApp(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: kRomagnaDarkGray,
              minimumSize: const Size.fromHeight(48),
              side: BorderSide(color: kRomagnaDarkGray.withValues(alpha: 0.22)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Chiudi e torna agli avvisi in app',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
