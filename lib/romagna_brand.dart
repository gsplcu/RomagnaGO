import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colore d'accento dell'interfaccia (sostituisce l'azzurro predefinito ovunque).
enum AppThemeAccent { blue, orange, red }

extension AppThemeAccentX on AppThemeAccent {
  String get label => switch (this) {
    AppThemeAccent.blue => 'Azzurro',
    AppThemeAccent.orange => 'Arancione',
    AppThemeAccent.red => 'Rosso',
  };

  Color get primary => themeAccentPrimary(this);

  Color get primaryLight => themeAccentPrimaryLight(this);
}

AppThemeAccent _romagnaThemeAccent = AppThemeAccent.blue;

Color themeAccentPrimary(AppThemeAccent accent) => switch (accent) {
  AppThemeAccent.blue => const Color(0xFF38B6FF),
  AppThemeAccent.orange => const Color(0xFFFF8A00),
  AppThemeAccent.red => const Color(0xFFE53935),
};

Color themeAccentPrimaryLight(AppThemeAccent accent) => switch (accent) {
  AppThemeAccent.blue => const Color(0xFF9DDCFF),
  AppThemeAccent.orange => const Color(0xFFFFCC80),
  AppThemeAccent.red => const Color(0xFFFFAB91),
};

void applyRomagnaThemeAccent(AppThemeAccent accent) {
  _romagnaThemeAccent = accent;
}

AppThemeAccent get currentRomagnaThemeAccent => _romagnaThemeAccent;

/// Colore tema corrente (azzurro, arancione o rosso secondo impostazioni).
Color get kRomagnaPrimary => themeAccentPrimary(_romagnaThemeAccent);

const Color kRomagnaDarkGray = Color(0xFF393939);

/// Metromare — allineato a pinpoint / bubble mappa.
const Color kMetromareRed = Color(0xFFC8104F);
const Color kMetromareRedDark = Color(0xFF9F0D40);
const Color kFerryElectricBlue = Color(0xFF1A73FF);

/// Attribuzione mappa OSM/tile (stile compatto), senza prefisso del nome del pacchetto mappa.
Widget romagnaMapAttributionChip({
  Alignment alignment = Alignment.bottomLeft,
  Color? backgroundColor,
  String text = '© OpenStreetMap · CARTO',
  TextStyle? textStyle,
}) {
  return SafeArea(
    child: Align(
      alignment: alignment,
      child: ColoredBox(
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.75),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Text(
            text,
            style:
                textStyle ??
                GoogleFonts.inter(
                  fontSize: 9,
                  color: kRomagnaDarkGray.withValues(alpha: 0.55),
                ),
          ),
        ),
      ),
    ),
  );
}

/// Bordo immagini guida (Altro > Aiuto, mappe illustrative).
const Color kRomagnaHelpImageBorderColor = Color(0xFFC5CDD6);

/// Contorno screenshot/guide (Altro > Aiuto): bordo grigio spesso + sfondo chiaro.
/// Con [tight] il bordo segue solo i contorni del [child], senza riempimento extra.
Widget romagnaHelpImageFrame({required Widget child, bool tight = false}) {
  const radius = 12.0;
  const borderWidth = 5.0;

  if (tight) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: kRomagnaHelpImageBorderColor,
          width: borderWidth,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - borderWidth),
        child: child,
      ),
    );
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: kRomagnaHelpImageBorderColor,
          width: borderWidth,
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ClipRect(
          child: Align(
            alignment: Alignment.center,
            widthFactor: 0.992,
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// Primo blocco numerico in etichetta linea (es. `94/94A` → 94, `11/11A` → 11).
int? romagnaLineLabelLeadingNumber(String line) {
  final m = RegExp(r'^(\d+)').firstMatch(line.trim());
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

/// Ordine crescente per numero iniziale; a parità di numero, ordine alfabetico.
int compareRomagnaLineLabels(String a, String b) {
  final ai = romagnaLineLabelLeadingNumber(a);
  final bi = romagnaLineLabelLeadingNumber(b);
  if (ai != null && bi != null) {
    final byNum = ai.compareTo(bi);
    if (byNum != 0) return byNum;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }
  if (ai != null) return -1;
  if (bi != null) return 1;
  return a.toLowerCase().compareTo(b.toLowerCase());
}

/// Voce menu senza [ListTile]: richiede un antenato [Material] (es. pagina Altro).
Widget romagnaMenuInkRow({
  required IconData icon,
  required String title,
  String? subtitle,
  VoidCallback? onTap,
  bool enabled = true,
  Color? iconColor,
}) {
  final titleColor =
      enabled ? kRomagnaDarkGray : kRomagnaDarkGray.withValues(alpha: 0.55);
  final leadingIconColor =
      enabled
          ? (iconColor ?? kRomagnaPrimary)
          : kRomagnaDarkGray.withValues(alpha: 0.36);
  return InkWell(
    onTap: enabled ? onTap : null,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: leadingIconColor,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color:
                          enabled
                              ? kRomagnaDarkGray.withValues(alpha: 0.58)
                              : kRomagnaDarkGray.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            enabled ? Icons.chevron_right_rounded : Icons.lock_outline_rounded,
            color:
                enabled
                    ? kRomagnaDarkGray.withValues(alpha: 0.45)
                    : kRomagnaDarkGray.withValues(alpha: 0.42),
          ),
        ],
      ),
    ),
  );
}
