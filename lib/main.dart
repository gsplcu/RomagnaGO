import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import 'app_settings.dart';
import 'firebase_options.dart';
import 'stop_visibility.dart';
import 'login_page.dart';
import 'photon_romagna.dart';
import 'romagna_brand.dart';
import 'altro_menu.dart';
import 'biglietto_menu.dart';
import 'quick_addresses.dart';
import 'quick_address_nearby_stops.dart';
import 'transit_stops.dart';
import 'transiti_at_stop.dart';
import 'linee_percorsi.dart';
import 'line_display.dart';
import 'stop_transit_schedule.dart';
import 'infobus_realtime.dart';
import 'transit_trip_open.dart';
import 'stop_all_departures_page.dart';
import 'service_calendar.dart';
import 'percorso/percorso_page.dart';
import 'percorso/percorso_search.dart';
import 'percorso/graphhopper_walk.dart';
import 'navette_page.dart';
import 'start_content/start_content_repository.dart';
import 'start_content/navetta_content_sync.dart';

// -----------------------------------------------------------------------------
// Punto d'ingresso: inizializza Flutter, poi Firebase con le opzioni FlutterFire
// (DefaultFirebaseOptions), quindi avvia l’app Material.
// -----------------------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    // Piattaforme non configurate in firebase_options o errore rete: log e avvio comunque.
    debugPrint('Firebase.initializeApp: $e\n$st');
  }
  unawaited(StartContentRepository.instance.warmUp());
  unawaited(NavettaContentSync.preloadNavette());
  runApp(const RomagnaGoApp());
}

// -----------------------------------------------------------------------------
// Palette brand (kRomagnaPrimary / kRomagnaDarkGray in romagna_brand.dart).
// -----------------------------------------------------------------------------
const Color kNavIconInactive = Color(0xFF9E9E9E);
const Color kSearchBorder = Color(0xFFDADADA);
const Color kMapBase = Color(0xFFE8ECEF);
const Color kSheetHandle = Color(0xFFC9CED4);
const Color kStopBusOrange = Color(0xFFFF8A00);
const Color kStopBusOrangeDark = Color(0xFFF57C00);
const Color kFerryElectricBlue = Color(0xFF1A73FF);
const Color kFerrySelectedDarkYellow = Color(0xFFFFC107);

/// Centro iniziale mappa (Romagna) e zoom richiesti (fallback se manca la posizione).
const LatLng kRomagnaMapCenter = LatLng(44.22, 12.24);
const double kRomagnaMapZoom = 10;
const double kRomagnaMapMinZoom = 8;
const double kRomagnaMapMaxZoom = 18;

/// Layer raster mappa (Carto, Esri, tile OSM Francia / HOT).
enum RomagnaMapRasterKind {
  whiteCarto,
  satelliteEsri,
  darkCarto,
  cyclOsm,
  humanitarianHot,
}

const String _kMapTileCartoLight =
    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
const String _kMapTileCartoDark =
    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
const List<String> _kMapTileSubdomainsCarto = ['a', 'b', 'c', 'd'];

/// Esri World Imagery (Web Mercator).
const String _kMapTileEsriWorldImagery =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

/// CyclOSM (OpenStreetMap France).
const String _kMapTileCyclOsm =
    'https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png';

/// Humanitarian OSM (HOT) — tile OpenStreetMap France.
const String _kMapTileHot =
    'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';

const List<String> _kMapTileSubdomainsOsmFr = ['a', 'b', 'c'];

({String urlTemplate, List<String> subdomains, int maxNativeZoom})
_rasterTileSpec(RomagnaMapRasterKind kind) {
  return switch (kind) {
    RomagnaMapRasterKind.whiteCarto => (
      urlTemplate: _kMapTileCartoLight,
      subdomains: _kMapTileSubdomainsCarto,
      maxNativeZoom: 19,
    ),
    RomagnaMapRasterKind.satelliteEsri => (
      urlTemplate: _kMapTileEsriWorldImagery,
      subdomains: const <String>[],
      maxNativeZoom: 19,
    ),
    RomagnaMapRasterKind.darkCarto => (
      urlTemplate: _kMapTileCartoDark,
      subdomains: _kMapTileSubdomainsCarto,
      maxNativeZoom: 19,
    ),
    RomagnaMapRasterKind.cyclOsm => (
      urlTemplate: _kMapTileCyclOsm,
      subdomains: _kMapTileSubdomainsOsmFr,
      maxNativeZoom: 20,
    ),
    RomagnaMapRasterKind.humanitarianHot => (
      urlTemplate: _kMapTileHot,
      subdomains: _kMapTileSubdomainsOsmFr,
      maxNativeZoom: 19,
    ),
  };
}

Color _mapRasterBackground(RomagnaMapRasterKind kind) {
  return switch (kind) {
    RomagnaMapRasterKind.whiteCarto => const Color(0xFFF2F2F0),
    RomagnaMapRasterKind.humanitarianHot => const Color(0xFFEAEAEA),
    RomagnaMapRasterKind.cyclOsm => const Color(0xFFF4F4F4),
    RomagnaMapRasterKind.darkCarto => const Color(0xFF121212),
    RomagnaMapRasterKind.satelliteEsri => const Color(0xFF1B1D1F),
  };
}

RomagnaMapRasterKind mapRasterForSettings(AppSettings s) {
  if (s.darkTheme && s.forceBlackMapWithDarkTheme) {
    return RomagnaMapRasterKind.darkCarto;
  }
  return switch (s.startupMapStyle) {
    AppStartupMapStyle.standard => RomagnaMapRasterKind.humanitarianHot,
    AppStartupMapStyle.satellite => RomagnaMapRasterKind.satelliteEsri,
    AppStartupMapStyle.cyclOsm => RomagnaMapRasterKind.cyclOsm,
    AppStartupMapStyle.white => RomagnaMapRasterKind.whiteCarto,
    AppStartupMapStyle.black => RomagnaMapRasterKind.darkCarto,
  };
}

/// Indice fisso nel picker layer (scroll orizzontale).
int _mapLayerPickerIndex(RomagnaMapRasterKind kind) {
  return switch (kind) {
    RomagnaMapRasterKind.humanitarianHot => 0,
    RomagnaMapRasterKind.satelliteEsri => 1,
    RomagnaMapRasterKind.cyclOsm => 2,
    RomagnaMapRasterKind.whiteCarto => 3,
    RomagnaMapRasterKind.darkCarto => 4,
  };
}

/// Larghezza tile picker + `SizedBox` tra una e l’altra.
const double _kMapLayerPickerTileStride = 152.0 + 10.0;

/// Evita [LatLng] non finiti o fuori range che mandano in errore flutter_map (tile layer).
bool isValidMapLatLng(LatLng p) {
  return p.latitude.isFinite &&
      p.longitude.isFinite &&
      p.latitude.abs() <= 90.0 &&
      p.longitude.abs() <= 180.0;
}

/// Confronto coordinate fermata / evidenziazione ricerca (tolleranza pochi metri).
bool pinsNearlySameLocation(LatLng a, LatLng b) {
  const distance = Distance();
  return distance.as(LengthUnit.Meter, a, b) < 6;
}

/// Risolve la [TransitStopPin] dall’hit ricerca (codice, nome visualizzato, coordinate).
TransitStopPin? transitStopPinForSearchHit(
  RomagnaAddressHit hit,
  List<TransitStopPin> allStops,
) {
  if (!hit.isBusStop || allStops.isEmpty) return null;
  final code = hit.transitStopCode?.trim();
  if (code != null && code.isNotEmpty) {
    for (final p in allStops) {
      if (p.stopId == code) return p;
    }
  }
  final rawName = hit.transitStopName?.trim();
  if (rawName != null && rawName.isNotEmpty) {
    final target = transitStopNameForDisplay(rawName);
    for (final p in allStops) {
      if (transitStopNameForDisplay(p.stopName) == target) return p;
    }
  }
  for (final p in allStops) {
    if (pinsNearlySameLocation(p.point, hit.point)) return p;
  }
  return null;
}

FerryStopPin? ferryStopPinForSearchHit(
  RomagnaAddressHit hit,
  List<FerryStopPin> allFerries,
) {
  if (!hit.isFerryStop || allFerries.isEmpty) return null;
  final rawName = hit.transitStopName?.trim();
  if (rawName != null && rawName.isNotEmpty) {
    final target = transitStopNameForDisplay(rawName);
    for (final f in allFerries) {
      if (transitStopNameForDisplay(f.stopName) == target) return f;
    }
  }
  for (final f in allFerries) {
    if (pinsNearlySameLocation(f.point, hit.point)) return f;
  }
  return null;
}

/// Icona elenco risultati ricerca in base al tipo di luogo (Photon / fermata).
IconData romagnaSearchHitLeadingIcon(RomagnaAddressHit hit) {
  if (hit.isSearchMessage) return Icons.info_outline_rounded;
  final isMetromare =
      hit.isMetromareStop ||
      (hit.transitStopCode?.trim().toUpperCase().startsWith('TRC') ?? false);
  if (hit.isFerryStop) return Icons.directions_boat_filled_rounded;
  if (isMetromare) return Icons.circle;
  if (hit.isBusStop) return Icons.directions_bus_rounded;
  switch (hit.placeKind) {
    case RomagnaSearchPlaceKind.busStop:
      return Icons.directions_bus_rounded;
    case RomagnaSearchPlaceKind.street:
      return Icons.alt_route_rounded;
    case RomagnaSearchPlaceKind.cityOrTown:
      return Icons.location_city_rounded;
    case RomagnaSearchPlaceKind.villageOrHamlet:
      return Icons.location_on_rounded;
    case RomagnaSearchPlaceKind.placeOfInterest:
      return Icons.storefront_outlined;
    case RomagnaSearchPlaceKind.addressBuilding:
      return Icons.home_work_outlined;
    case RomagnaSearchPlaceKind.other:
      return Icons.place_outlined;
  }
}

Color romagnaSearchHitLeadingColor(RomagnaAddressHit hit) {
  if (hit.isSearchMessage) return kRomagnaDarkGray.withValues(alpha: 0.5);
  final isMetromare =
      hit.isMetromareStop ||
      (hit.transitStopCode?.trim().toUpperCase().startsWith('TRC') ?? false);
  if (hit.isFerryStop) return kFerryElectricBlue;
  if (isMetromare) return kMetromareRed;
  if (hit.isBusStop) return kRomagnaPrimary.withValues(alpha: 0.88);
  return kRomagnaPrimary.withValues(alpha: 0.88);
}

Widget romagnaSearchHitLeadingWidget(RomagnaAddressHit hit) {
  final isMetromare =
      hit.isMetromareStop ||
      (hit.transitStopCode?.trim().toUpperCase().startsWith('TRC') ?? false);
  if (isMetromare) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: kMetromareRed,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        'M',
        style: GoogleFonts.comicNeue(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );
  }
  return Icon(
    romagnaSearchHitLeadingIcon(hit),
    size: 22,
    color: romagnaSearchHitLeadingColor(hit),
  );
}

/// Titolo riga autocomplete (nome fermata o label indirizzo).
Widget romagnaSearchHitListTitle(RomagnaAddressHit hit) {
  if (hit.isSearchMessage) {
    return Text(
      hit.label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        fontSize: 13.5,
        height: 1.25,
        color: kRomagnaDarkGray.withValues(alpha: 0.68),
      ),
    );
  }
  final name = hit.transitStopName;
  if (hit.isBusStop && name != null && name.isNotEmpty) {
    return Text(
      transitStopNameForDisplay(name),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        fontSize: 13.5,
        height: 1.25,
        color: kRomagnaDarkGray,
        fontWeight: FontWeight.w600,
      ),
    );
  }
  return Text(
    hit.label,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: GoogleFonts.inter(
      fontSize: 13.5,
      height: 1.25,
      color: kRomagnaDarkGray,
    ),
  );
}

/// Codice fermata sotto il titolo ([ListTile.subtitle]); null per hit non-TPL.
Widget? romagnaSearchHitListSubtitle(RomagnaAddressHit hit) {
  if (hit.isSearchMessage) return null;
  final code = hit.transitStopCode;
  if (!hit.isBusStop || code == null || code.isEmpty) return null;
  return Text(
    code,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: GoogleFonts.inter(
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: romagnaSearchHitLeadingColor(hit),
    ),
  );
}

/// [MapController.move] con centro e zoom sempre finiti (recupero da stati corrotti / API anomale).
void safeMapMove(
  MapController controller,
  LatLng center,
  double zoom, {
  Offset offset = Offset.zero,
}) {
  final c = isValidMapLatLng(center) ? center : kRomagnaMapCenter;
  var z = zoom.isFinite ? zoom : kRomagnaMapZoom;
  z = z.clamp(kRomagnaMapMinZoom, kRomagnaMapMaxZoom);
  if (!z.isFinite) z = kRomagnaMapZoom;
  controller.move(c, z, offset: offset);
}

/// Zoom quando la posizione dell’utente è disponibile (strada / contesto locale).
const double kUserLocationZoom = 14;

/// Zoom dopo ricerca indirizzo (via / quartiere).
const double kSearchResultZoom = 15.5;
const double kQuickAddressZoom = 16;

/// Altezza overlay in cima alla mappa (barra ricerca + pill Indirizzi rapidi/Biglietto).
const double kMapSearchChromeTopPx = -100;

/// Fermate vicine mostrate nel foglio (posizione attuale / indirizzi rapidi).
const int kNearbyStopsMaxResults = 3;

/// Altezza tendina quando aperta per fermate vicine / selezione (sotto il 50% schermo).
const double kSheetSnapHalfFraction = 0.50;

/// Striscia in alto sul foglio (maniglia) usata per ridimensionare il pannello.
const double kSheetSnapDragStripPx = 32;

/// Riga chip «Mezzi pubblici» / «Mobilità elettrica».
const double kSheetSnapFilterRowPx = 44;

/// Foglio in posizione bassa: maniglia + sola riga tab (padding verticale minimo).
const double kSheetSnapLowPx =
    kSheetSnapDragStripPx + kSheetSnapFilterRowPx + 10;

/// Stima altezza sotto al SafeArea (ricerca + pill) oltre la quale non sale il foglio «alto».
const double kSheetFullSnapTopChromeExtraPx = 118;

typedef _SheetSnapGeom = ({double low, double mid, double full, double half});

_SheetSnapGeom _sheetSnapGeom(MediaQueryData mq, double h) {
  final topChromePx = mq.padding.top + kSheetFullSnapTopChromeExtraPx;
  final full = ((h - topChromePx - 10) / h).clamp(0.48, 0.985);
  final low = (kSheetSnapLowPx / h).clamp(0.07, 0.22);
  final half = kSheetSnapHalfFraction.clamp(low + 0.04, full - 0.04);
  return (low: low, mid: half, full: full, half: half);
}

bool _sheetIsAtLowSnap(double extent, double snapLow) =>
    (extent - snapLow).abs() < 0.012;

bool _hasExplicitSheetSelection(BusStopSheetLinesPayload? p) {
  if (p == null) return false;
  if (p.quickAddressDetail != null) return true;
  if (p.isFerry) return true;
  if (p.nearbyOriginPoint != null && !p.nearbyAnchoredToUserLocation) {
    return true;
  }
  return p.stopId?.trim().isNotEmpty ?? false;
}

// -----------------------------------------------------------------------------
// Scroll: su web/desktop il drag col mouse deve pilotare gli scrollable; il
// default Material spesso esclude il mouse.
// -----------------------------------------------------------------------------
class RomagnaScrollBehavior extends MaterialScrollBehavior {
  const RomagnaScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.mouse,
  };
}

// -----------------------------------------------------------------------------
// Applicazione principale: Material 3, tema tipografico (Inter) e navigazione.
// -----------------------------------------------------------------------------
class RomagnaGoApp extends StatefulWidget {
  const RomagnaGoApp({super.key});

  @override
  State<RomagnaGoApp> createState() => _RomagnaGoAppState();
}

class _RomagnaGoAppState extends State<RomagnaGoApp> {
  final AppSettingsController _settingsController = AppSettingsController();

  @override
  void initState() {
    super.initState();
    _settingsController.load();
  }

  @override
  void dispose() {
    _settingsController.dispose();
    super.dispose();
  }

  TextTheme _titlesWithTracking(TextTheme base) {
    double track(TitleStyle style) => switch (style) {
      TitleStyle.large => 0.35,
      TitleStyle.medium => 0.3,
      TitleStyle.small => 0.25,
    };

    return base.copyWith(
      titleLarge: base.titleLarge?.copyWith(
        letterSpacing: track(TitleStyle.large),
      ),
      titleMedium: base.titleMedium?.copyWith(
        letterSpacing: track(TitleStyle.medium),
      ),
      titleSmall: base.titleSmall?.copyWith(
        letterSpacing: track(TitleStyle.small),
      ),
      headlineSmall: base.headlineSmall?.copyWith(letterSpacing: 0.3),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: kRomagnaPrimary,
      brightness: brightness,
    );
    final onSurface =
        brightness == Brightness.dark ? Colors.white : kRomagnaDarkGray;
    final interTextTheme = GoogleFonts.interTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );
    final textTheme = _titlesWithTracking(
      interTextTheme.apply(bodyColor: onSurface, displayColor: onSurface),
    );
    final surface =
        brightness == Brightness.dark
            ? const Color(0xFF121212)
            : const Color(0xFFFAFAFA);
    final navBg =
        brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: textTheme,
      colorScheme: baseScheme.copyWith(
        primary: kRomagnaPrimary,
        onPrimary: Colors.white,
        secondary: kRomagnaPrimary,
        surface: surface,
        onSurface: onSurface,
      ),
      scaffoldBackgroundColor: surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: navBg,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: navBg,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black26,
        elevation: 8,
        indicatorColor: kRomagnaPrimary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? kRomagnaPrimary : kNavIconInactive,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? kRomagnaPrimary : kNavIconInactive,
            size: 24,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            brightness == Brightness.dark
                ? const Color(0xFF2A2A2A)
                : Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: kSearchBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: kRomagnaPrimary, width: 1.2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: kSearchBorder, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        hintStyle: GoogleFonts.inter(color: onSurface.withValues(alpha: 0.55)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settingsController,
      builder: (context, _) {
        final settings = _settingsController.value;
        final textFactor = settings.textSizeScale.factor;
        return AppSettingsScope(
          controller: _settingsController,
          child: MaterialApp(
            title: 'RomagnaGO',
            debugShowCheckedModeBanner: false,
            locale: const Locale('it', 'IT'),
            supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            themeMode: settings.darkTheme ? ThemeMode.dark : ThemeMode.light,
            scrollBehavior: const RomagnaScrollBehavior(),
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              final scaled = TextScaler.linear(
                mq.textScaler.scale(1) * textFactor,
              );
              return MediaQuery(
                data: mq.copyWith(textScaler: scaled),
                child: GestureDetector(
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  behavior: HitTestBehavior.deferToChild,
                  child: child,
                ),
              );
            },
            home: const LoginPage(),
            routes: {'/home': (_) => const RomagnaHomePage()},
          ),
        );
      },
    );
  }
}

enum TitleStyle { large, medium, small }

/// Esito scelta indirizzo nello slot (manuale può richiedere aggiustamento su mappa).
class _SlotPickOutcome {
  const _SlotPickOutcome({required this.hit});

  final RomagnaAddressHit hit;
}

// -----------------------------------------------------------------------------
// Home Page: layout tipo WienMobil (mappa Carto Positron + sheet + overlay + 4 tab in basso).
// -----------------------------------------------------------------------------
class RomagnaHomePage extends StatefulWidget {
  const RomagnaHomePage({super.key});

  @override
  State<RomagnaHomePage> createState() => _RomagnaHomePageState();
}

class _RomagnaHomePageState extends State<RomagnaHomePage>
    with WidgetsBindingObserver {
  static const int _minSearchChars = 3;

  int _navIndex = 0;
  int _sheetFilterIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();

  final ValueNotifier<LatLng?> _userPointNotifier = ValueNotifier<LatLng?>(
    null,
  );

  final ValueNotifier<LatLng?> _searchPinNotifier = ValueNotifier<LatLng?>(
    null,
  );

  /// Indirizzo generico ancorato al pin azzurro (per riselezione al tap sul marker).
  RomagnaAddressHit? _mapSearchAddressHit;

  /// Fermata scelta dalla barra ricerca: niente pin azzurro, solo evidenziazione sul marker bus.
  final ValueNotifier<LatLng?> _searchBusStopHighlightNotifier =
      ValueNotifier<LatLng?>(null);
  final ValueNotifier<QuickAddressesState> _quickAddressNotifier =
      ValueNotifier<QuickAddressesState>(QuickAddressesState.empty);

  /// Invalida il calcolo fermate vicine se l’utente tocca un altro indirizzo rapido.
  int _quickAddressNearbyGen = 0;
  int _userLocationNearbyGen = 0;
  int _searchAddressNearbyGen = 0;

  /// Evita refresh parziali mentre si prepara la prima presentazione GPS all’avvio.
  bool _initialLocationPresentationPending = false;
  final FocusNode _mapSearchFocusNode = FocusNode();
  final ValueNotifier<int> _mapSearchDismissTick = ValueNotifier<int>(0);

  /// Ultima altezza area mappa ([LayoutBuilder]) per calcolo snap foglio.
  double _mapStackHeightCache = 0;

  /// Dopo deselezione pinpoint: foglio resta alzato con «Nessun risultato»; il tap successivo lo chiude.
  bool _sheetIdleAfterPinDeselect = false;

  Timer? _recenterStopLayoutTimer;
  double? _lastKeyboardInsetBottom;

  void _onMapSearchFocusChangedForRecenter() {
    if (_mapSearchFocusNode.hasFocus) return;
    _scheduleRecenterSelectedStopAfterKeyboard();
  }

  void _scheduleRecenterSelectedStopAfterKeyboard() {
    if (_sheetIdleAfterPinDeselect) return;
    _recenterStopLayoutTimer?.cancel();
    _recenterStopLayoutTimer = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      _romagnaMapStateKey.currentState?.recenterSelectedPinForSheetLayout();
    });
  }

  /// Tap su mappa senza marker: chiude selezioni, tendina se vuota, e azzera la barra ricerca se c’era un ancoraggio.
  void _handleRomagnaMapBlankTap() {
    final hadMapPinpoint =
        _romagnaMapStateKey.currentState?.hasSelectedMapPinpoint() ?? false;

    final hadMapAnchor =
        _busStopSheetLinesNotifier.value != null ||
        _searchPinNotifier.value != null ||
        _searchBusStopHighlightNotifier.value != null;

    _romagnaMapStateKey.currentState?.clearMapSelectionsForBlankTap();

    _mapSearchDismissTick.value++;
    _mapSearchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    if (hadMapAnchor) {
      _searchController.clear();
      _searchPinNotifier.value = null;
      _searchBusStopHighlightNotifier.value = null;
      _mapSearchAddressHit = null;
    }

    if (hadMapPinpoint || hadMapAnchor) {
      _userLocationNearbyGen++;
      _searchAddressNearbyGen++;
      _quickAddressNearbyGen++;
      _busStopSheetLinesNotifier.value = null;
      setState(() => _sheetIdleAfterPinDeselect = true);
      return;
    }

    if (_sheetIdleAfterPinDeselect) {
      setState(() => _sheetIdleAfterPinDeselect = false);
    }

    _collapseSheetIfIdleAfterMapTap();
  }

  /// Dopo tap sulla mappa senza selezione nel foglio: abbassa la tendina (fermate vicine restano).
  void _collapseSheetIfIdleAfterMapTap() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _navIndex != 0 || _sheetFilterIndex != 0) return;
      if (_hasExplicitSheetSelection(_busStopSheetLinesNotifier.value)) return;
      final h = _mapStackHeightCache;
      if (h <= 0) return;
      final snapLow = (kSheetSnapLowPx / h).clamp(0.07, 0.22);
      setState(() => _sheetExtent = snapLow);
      _resetSheetScrollToTop();
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _navIndex != 0) return;
      final bottom = MediaQuery.viewInsetsOf(context).bottom;
      final prev = _lastKeyboardInsetBottom;
      _lastKeyboardInsetBottom = bottom;
      if (prev != null && prev > 8 && bottom <= 8) {
        _scheduleRecenterSelectedStopAfterKeyboard();
      }
    });
  }

  /// Ascolto continuo della posizione dopo il primo fix (annullato in dispose).
  StreamSubscription<Position>? _positionSubscription;
  late final Future<void> _mapLoadFuture;

  /// Fermate TPL da asset JSON (coordinate deduplicate tra file).
  List<TransitStopPin> _busStops = const [];
  List<FerryStopPin> _ferryStops = const [];
  TransitiStopLinesIndex _transitiIndex = TransitiStopLinesIndex.empty();

  /// `true` se [TransitiStopLinesIndex.load] ha fallito (si usa indice vuoto).
  bool _transitiCatalogLoadFailed = false;
  StopTransitScheduleIndex _scheduleIndex = StopTransitScheduleIndex.empty();
  bool _scheduleLoadFailed = false;
  Map<String, RomagnaLineaRow> _lineeByComposite = const {};
  final ValueNotifier<BusStopSheetLinesPayload?> _busStopSheetLinesNotifier =
      ValueNotifier<BusStopSheetLinesPayload?>(null);

  /// Nomi fermata (strict) con almeno una linea extraurbana in transiti.
  final Set<String> _extraurbanStopNames = {};

  AppSettingsController? _settingsCtrl;

  /// Altezza relativa del foglio (0–1): posiziona il FAB sopra il bordo superiore dello sheet.
  /// Valore iniziale a metà schermo (uno dei 3 snap: low, half, full).
  double _sheetExtent = kSheetSnapHalfFraction;
  bool _sheetDragByUserInProgress = false;

  final ScrollController _sheetScrollController = ScrollController();
  OverlayEntry? _quickUndoOverlayEntry;

  final GlobalKey<_RomagnaMapState> _romagnaMapStateKey =
      GlobalKey<_RomagnaMapState>();

  void _openBiglietto(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (context) => const BigliettoMenuPage()),
    );
  }

  LatLng _searchPriorityOrigin() {
    final current = _userPointNotifier.value;
    final fallback = kRomagnaSearchFallbackOrigin;
    if (current == null || !isValidMapLatLng(current)) return fallback;
    return current;
  }

  AppSettings get _settings => AppSettingsScope.of(context).value;

  List<TransitStopPin> _visibleBusStopsFor(AppSettings s) {
    Iterable<TransitStopPin> list = _busStops;
    switch (s.stopVisibility) {
      case StopVisibilityOption.all:
        break;
      case StopVisibilityOption.fc:
        list = list.where((p) => p.basin == 'fc');
        break;
      case StopVisibilityOption.rn:
        list = list.where((p) => p.basin == 'rn');
        break;
      case StopVisibilityOption.ra:
        list = list.where((p) => p.basin == 'ra');
        break;
    }
    if (s.extraurbanStopsOnly) {
      list = list.where((p) => _extraurbanStopNames.contains(p.stopName));
    }
    switch (s.metromareFilter) {
      case MetromareMapFilter.hide:
        list = list.where((p) => !isMetromareStopId(p.stopId));
        break;
      case MetromareMapFilter.onlyMetromare:
        list = list.where((p) => isMetromareStopId(p.stopId));
        break;
      case MetromareMapFilter.show:
        break;
    }
    if (!s.showBusStops) {
      list = list.where((p) => isMetromareStopId(p.stopId));
    }
    return list.toList(growable: false);
  }

  List<TransitStopPin> get _visibleBusStops => _visibleBusStopsFor(_settings);

  List<FerryStopPin> get _visibleFerryStops =>
      _settings.showFerryRavennaStops ? _ferryStops : const [];

  /// GPS corrente per salvare Casa/Lavoro (dialog indirizzo rapido). Non sposta la mappa da sola.
  Future<RomagnaAddressHit?> _readCurrentPositionForQuickAddress() async {
    if (!mounted) return null;
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        _snackDiscreet('Attiva il GPS per usare la posizione attuale.');
        return null;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.unableToDetermine) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        _snackDiscreet(
          'Posizione bloccata. Abilitala nelle impostazioni di sistema.',
        );
        return null;
      }
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm != LocationPermission.whileInUse &&
            perm != LocationPermission.always) {
          _snackDiscreet('Permesso posizione necessario per questa funzione.');
          return null;
        }
      }
      if (perm != LocationPermission.whileInUse &&
          perm != LocationPermission.always) {
        _snackDiscreet('Posizione non disponibile.');
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return null;
      final here = LatLng(pos.latitude, pos.longitude);
      if (!isValidMapLatLng(here)) {
        _snackDiscreet('Coordinate non valide.');
        return null;
      }
      _userPointNotifier.value = here;

      final rev = await reverseRomagnaPlace(here);
      final label =
          rev != null
              ? 'Posizione attuale · ${rev.formatted}'
              : 'Posizione attuale';

      return RomagnaAddressHit(
        label: label,
        point: here,
        isBusStop: false,
        placeKind: RomagnaSearchPlaceKind.other,
      );
    } on TimeoutException {
      if (mounted) {
        _snackDiscreet('Timeout lettura posizione. Riprova tra poco.');
      }
      return null;
    } catch (e, st) {
      debugPrint('Indirizzo rapido GPS: $e\n$st');
      if (mounted) {
        _snackDiscreet('Impossibile leggere la posizione.');
      }
      return null;
    }
  }

  void _setQuickAddresses(QuickAddressesState s) {
    _quickAddressNotifier.value = s;
    saveQuickAddressesToPrefs(s);
  }

  void _dismissMapSearchBar() {
    _mapSearchDismissTick.value++;
    _mapSearchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// Cancella testo barra ricerca, pin azzurro e evidenziazione fermata da ricerca.
  void _clearMapSearchFieldAndPins() {
    _mapSearchDismissTick.value++;
    _mapSearchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    _searchController.clear();
    _searchPinNotifier.value = null;
    _searchBusStopHighlightNotifier.value = null;
    _mapSearchAddressHit = null;
    _refreshAutoNearbyStopsIfNeeded();
  }

  void _clearSearchPinOnly() {
    final had = _searchPinNotifier.value != null;
    _searchPinNotifier.value = null;
    _mapSearchAddressHit = null;
    if (had) {
      _mapSearchDismissTick.value++;
      _searchController.clear();
      _refreshAutoNearbyStopsIfNeeded();
    }
  }

  /// Tap sul pin azzurro: assorbe l’evento (no zoom/centro/deselezione).
  void _onMapSearchPinTapped() {}

  Future<void> _pickQuickSlot({
    required String slotTitle,
    NamedQuickAddress? replaceExtra,
    String? extraIconKey,
  }) async {
    final outcome = await showDialog<_SlotPickOutcome>(
      context: context,
      builder:
          (_) => _QuickAddressSlotPickerDialog(
            title: slotTitle,
            minSearchChars: _minSearchChars,
            transitStops: _visibleBusStops,
            ferryStops: _visibleFerryStops,
            priorityOriginResolver: _searchPriorityOrigin,
            readCurrentLocationAsHit: _readCurrentPositionForQuickAddress,
          ),
    );
    if (!mounted || outcome == null) return;
    final hit = outcome.hit;
    final cur = _quickAddressNotifier.value;
    if (replaceExtra != null) {
      _setQuickAddresses(
        cur.replaceExtra(
          NamedQuickAddress(
            id: replaceExtra.id,
            tag: replaceExtra.tag,
            hit: hit,
            iconKey: replaceExtra.iconKey,
          ),
        ),
      );
    } else if (slotTitle == 'Casa') {
      _setQuickAddresses(cur.copyWith(home: hit));
    } else if (slotTitle == 'Lavoro') {
      _setQuickAddresses(cur.copyWith(work: hit));
    } else {
      _setQuickAddresses(
        cur.withExtra(
          NamedQuickAddress(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            tag: slotTitle,
            hit: hit,
            iconKey: quickAddressIconKeyNormalized(
              extraIconKey,
              fallbackTag: slotTitle,
            ),
          ),
        ),
      );
    }
    _scheduleCenterPointInVisibleBand(hit.point, zoom: kQuickAddressZoom);
  }

  void _scheduleCenterPointInVisibleBand(
    LatLng point, {
    double zoom = kRomagnaMapMaxZoom,
    double visualAnchorOffsetPx = 0,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _romagnaMapStateKey.currentState?.centerPointInVisibleBand(
        point,
        zoom: zoom,
        visualAnchorOffsetPx: visualAnchorOffsetPx,
      );
    });
  }

  /// Centra il pin indirizzo dopo che la tendina è a metà schermo (doppio frame).
  void _scheduleCenterSearchAddressPin(LatLng point) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final h = _mapStackHeightCache;
      if (h > 0) {
        final g = _sheetSnapGeom(MediaQuery.of(context), h);
        if ((_sheetExtent - g.half).abs() > 0.02) {
          setState(() => _sheetExtent = g.half);
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _romagnaMapStateKey.currentState?.centerSearchAddressPin(point);
      });
    });
  }

  QuickAddressMarkerTapDetails? _quickAddressDetailAfterEdit(
    QuickAddressMarkerTapDetails previous,
  ) {
    final st = _quickAddressNotifier.value;
    switch (previous.slotKind) {
      case QuickAddressSlotKind.home:
        final h = st.home;
        if (h == null) return null;
        return QuickAddressMarkerTapDetails(
          title: 'Casa',
          icon: Icons.home_rounded,
          hit: h,
          slotKind: QuickAddressSlotKind.home,
        );
      case QuickAddressSlotKind.work:
        final w = st.work;
        if (w == null) return null;
        return QuickAddressMarkerTapDetails(
          title: 'Lavoro',
          icon: Icons.work_outline_rounded,
          hit: w,
          slotKind: QuickAddressSlotKind.work,
        );
      case QuickAddressSlotKind.extra:
        final id = previous.namedExtra?.id;
        if (id == null) return null;
        for (final e in st.extras) {
          if (e.id == id) {
            return QuickAddressMarkerTapDetails(
              title: e.tag,
              icon: quickAddressIconDataForKey(e.iconKey),
              hit: e.hit,
              slotKind: QuickAddressSlotKind.extra,
              namedExtra: e,
            );
          }
        }
        return null;
    }
  }

  void _showSearchAddressNearbyInBottomSheet(RomagnaAddressHit hit) {
    _searchAddressNearbyGen++;
    final gen = _searchAddressNearbyGen;
    final origin = hit.point;

    if (_sheetIdleAfterPinDeselect) {
      setState(() => _sheetIdleAfterPinDeselect = false);
    }

    _busStopSheetLinesNotifier.value = BusStopSheetLinesPayload(
      bubbles: const [],
      catalogLoadFailed: false,
      scheduleLoadFailed: false,
      nearbyOriginPoint: origin,
      nearbyStops: const [],
      nearbyPending: true,
      nearbyAnchoredToUserLocation: false,
      nearbyAnchorLabel:
          hit.label.trim().isNotEmpty ? hit.label : romagnaHitDisplayLine(hit),
    );

    final stopsSnapshot = List<TransitStopPin>.from(_visibleBusStops);

    unawaited(
      Future<void>(() async {
        final nearby = nearestMergedTransitStops(
          origin,
          stopsSnapshot,
          maxResults: kNearbyStopsMaxResults,
        );
        if (!mounted) return;
        if (gen != _searchAddressNearbyGen) return;
        final snap = _busStopSheetLinesNotifier.value;
        if (snap == null || snap.nearbyAnchoredToUserLocation) return;
        if (snap.nearbyOriginPoint == null) return;
        if (!pinsNearlySameLocation(snap.nearbyOriginPoint!, origin)) return;
        if (_searchPinNotifier.value == null ||
            !pinsNearlySameLocation(_searchPinNotifier.value!, origin)) {
          return;
        }

        _busStopSheetLinesNotifier.value = BusStopSheetLinesPayload(
          bubbles: const [],
          catalogLoadFailed: false,
          scheduleLoadFailed: false,
          nearbyOriginPoint: origin,
          nearbyStops: nearby,
          nearbyPending: false,
          nearbyAnchoredToUserLocation: false,
          nearbyAnchorLabel: snap.nearbyAnchorLabel,
        );
      }),
    );
  }

  void _showQuickAddressInBottomSheet(QuickAddressMarkerTapDetails d) {
    _quickAddressNearbyGen++;
    final gen = _quickAddressNearbyGen;

    if (_sheetIdleAfterPinDeselect) {
      setState(() => _sheetIdleAfterPinDeselect = false);
    }

    _busStopSheetLinesNotifier.value = BusStopSheetLinesPayload(
      quickAddressDetail: d,
      quickAddressNearbyStops: const [],
      quickAddressNearbyPending: true,
      bubbles: const [],
      catalogLoadFailed: false,
      scheduleLoadFailed: false,
    );

    _scheduleCenterPointInVisibleBand(d.hit.point, zoom: kQuickAddressZoom);

    final origin = d.hit.point;
    final stopsSnapshot = List<TransitStopPin>.from(_visibleBusStops);

    unawaited(
      Future<void>(() async {
        final nearby = nearestMergedTransitStops(
          origin,
          stopsSnapshot,
          maxResults: kNearbyStopsMaxResults,
        );
        if (!mounted) return;
        if (gen != _quickAddressNearbyGen) return;
        final snap = _busStopSheetLinesNotifier.value;
        final q = snap?.quickAddressDetail;
        if (snap == null || q == null) return;
        if (!pinsNearlySameLocation(q.hit.point, d.hit.point)) return;

        _busStopSheetLinesNotifier.value = BusStopSheetLinesPayload(
          quickAddressDetail: q,
          quickAddressNearbyStops: nearby,
          quickAddressNearbyPending: false,
          bubbles: const [],
          catalogLoadFailed: false,
          scheduleLoadFailed: false,
        );
      }),
    );
  }

  void _expandSheetToHalfIfCollapsed({LatLng? recenterPoint}) {
    if (!mounted || _navIndex != 0) return;
    final h = _mapStackHeightCache;
    if (h <= 0) return;
    final g = _sheetSnapGeom(MediaQuery.of(context), h);
    if (_sheetExtent > g.low + 0.02) {
      if (recenterPoint != null) {
        _scheduleCenterPointInVisibleBand(recenterPoint);
      }
      return;
    }
    setState(() => _sheetExtent = g.half);
    if (recenterPoint != null) {
      _scheduleCenterPointInVisibleBand(recenterPoint);
    }
  }

  /// Aggiorna il foglio con le fermate vicine alla posizione attuale (se nessuna fermata è selezionata).
  void _refreshAutoNearbyStopsIfNeeded({bool expandSheetIfCollapsed = false}) {
    if (!mounted || _navIndex != 0 || _sheetFilterIndex != 0) return;
    if (_sheetIdleAfterPinDeselect) return;
    if (_hasExplicitSheetSelection(_busStopSheetLinesNotifier.value)) return;
    if (_searchPinNotifier.value != null) return;

    final current = _userPointNotifier.value;
    if (current == null || !isValidMapLatLng(current)) {
      _userLocationNearbyGen++;
      _busStopSheetLinesNotifier.value = null;
      return;
    }

    if (expandSheetIfCollapsed) {
      _expandSheetToHalfIfCollapsed(recenterPoint: current);
    }

    _userLocationNearbyGen++;
    final gen = _userLocationNearbyGen;
    final stopsSnapshot = List<TransitStopPin>.from(_visibleBusStops);

    _busStopSheetLinesNotifier.value = BusStopSheetLinesPayload(
      bubbles: const [],
      catalogLoadFailed: false,
      scheduleLoadFailed: false,
      nearbyOriginPoint: current,
      nearbyStops: const [],
      nearbyPending: true,
      nearbyAnchoredToUserLocation: true,
    );

    unawaited(
      Future<void>(() async {
        final nearby = nearestMergedTransitStops(
          current,
          stopsSnapshot,
          maxResults: kNearbyStopsMaxResults,
        );
        if (!mounted) return;
        if (gen != _userLocationNearbyGen) return;
        final snap = _busStopSheetLinesNotifier.value;
        if (snap?.nearbyOriginPoint == null) return;
        if (_hasExplicitSheetSelection(snap)) return;
        if (snap != null && !snap.nearbyAnchoredToUserLocation) return;
        if (!pinsNearlySameLocation(snap!.nearbyOriginPoint!, current)) return;

        _busStopSheetLinesNotifier.value = BusStopSheetLinesPayload(
          bubbles: const [],
          catalogLoadFailed: false,
          scheduleLoadFailed: false,
          nearbyOriginPoint: current,
          nearbyStops: nearby,
          nearbyPending: false,
          nearbyAnchoredToUserLocation: true,
        );
      }),
    );
  }

  void _onBusStopSheetLinesChangedForAutoNearby() {
    if (!mounted || _navIndex != 0) return;
    final p = _busStopSheetLinesNotifier.value;
    if (_hasExplicitSheetSelection(p)) {
      if (_sheetIdleAfterPinDeselect) {
        setState(() => _sheetIdleAfterPinDeselect = false);
      }
      _expandSheetToHalfIfCollapsed();
      return;
    }
    if (_sheetIdleAfterPinDeselect) return;
    // Evita loop: l’aggiornamento fermate vicine scrive già su questo notifier.
    if (p?.nearbyOriginPoint != null) return;
    _refreshAutoNearbyStopsIfNeeded();
  }

  void _onUserPointChangedForAutoNearby() {
    if (_initialLocationPresentationPending) return;
    if (!mounted || _navIndex != 0) return;
    if (_sheetIdleAfterPinDeselect) return;
    if (_searchPinNotifier.value != null) return;
    if (_hasExplicitSheetSelection(_busStopSheetLinesNotifier.value)) return;
    _refreshAutoNearbyStopsIfNeeded();
  }

  /// Dopo GPS + mappa pronti: zoom sulla posizione, tendina con fermate vicine.
  Future<void> _presentUserLocationOnMap(
    LatLng here, {
    required bool openingPresentation,
  }) async {
    if (!mounted || !isValidMapLatLng(here)) return;

    await _mapLoadFuture;
    if (!mounted) return;

    for (var i = 0; i < 40; i++) {
      if (_mapStackHeightCache > 0 &&
          _romagnaMapStateKey.currentState != null) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
    }

    if (!mounted) return;

    if (openingPresentation && _mapStackHeightCache > 0) {
      final g = _sheetSnapGeom(MediaQuery.of(context), _mapStackHeightCache);
      setState(() => _sheetExtent = g.half);
    } else {
      _expandSheetToHalfIfCollapsed(recenterPoint: here);
    }

    _refreshAutoNearbyStopsIfNeeded();
    _scheduleCenterPointInVisibleBand(here);
    _initialLocationPresentationPending = false;
  }

  Future<void> _pickQuickSlotFromMarkerDetail(
    QuickAddressMarkerTapDetails d,
  ) async {
    switch (d.slotKind) {
      case QuickAddressSlotKind.home:
        await _pickQuickSlot(slotTitle: 'Casa');
        break;
      case QuickAddressSlotKind.work:
        await _pickQuickSlot(slotTitle: 'Lavoro');
        break;
      case QuickAddressSlotKind.extra:
        final e = d.namedExtra;
        if (e != null) {
          await _pickQuickSlot(slotTitle: e.tag, replaceExtra: e);
        }
        break;
    }
    if (!mounted) return;
    final refreshed = _quickAddressDetailAfterEdit(d);
    if (refreshed != null) {
      _showQuickAddressInBottomSheet(refreshed);
    } else {
      _busStopSheetLinesNotifier.value = null;
    }
  }

  void _removeQuickAddressFromMarkerDetail(QuickAddressMarkerTapDetails d) {
    final cur = _quickAddressNotifier.value;
    switch (d.slotKind) {
      case QuickAddressSlotKind.home:
        _removeQuickAddressWithUndo(next: cur.copyWith(clearHome: true));
        break;
      case QuickAddressSlotKind.work:
        _removeQuickAddressWithUndo(next: cur.copyWith(clearWork: true));
        break;
      case QuickAddressSlotKind.extra:
        final id = d.namedExtra?.id;
        if (id != null) {
          _removeQuickAddressWithUndo(next: cur.removeExtraById(id));
        }
        break;
    }
    _busStopSheetLinesNotifier.value = null;
  }

  Future<void> _openIndirizziRapidiSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: ValueListenableBuilder<QuickAddressesState>(
              valueListenable: _quickAddressNotifier,
              builder: (context, st, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: kSheetHandle,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Text(
                      'Indirizzi rapidi',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: kRomagnaDarkGray,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Salva fino a cinque punti (Casa, Lavoro e altri con nome a tua scelta)',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        height: 1.35,
                        color: kRomagnaDarkGray.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(ctx).height * 0.52,
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          _QuickSheetRow(
                            icon: Icons.home_rounded,
                            title: 'Casa',
                            subtitle:
                                st.home == null
                                    ? 'Aggiungi'
                                    : romagnaHitDisplayLine(st.home!),
                            onTap: () {
                              Navigator.pop(ctx);
                              _pickQuickSlot(slotTitle: 'Casa');
                            },
                            onRemove:
                                st.home != null
                                    ? () {
                                      _removeQuickAddressWithUndo(
                                        next: st.copyWith(clearHome: true),
                                      );
                                    }
                                    : null,
                          ),
                          _QuickSheetRow(
                            icon: Icons.work_outline_rounded,
                            title: 'Lavoro',
                            subtitle:
                                st.work == null
                                    ? 'Aggiungi'
                                    : romagnaHitDisplayLine(st.work!),
                            onTap: () {
                              Navigator.pop(ctx);
                              _pickQuickSlot(slotTitle: 'Lavoro');
                            },
                            onRemove:
                                st.work != null
                                    ? () {
                                      _removeQuickAddressWithUndo(
                                        next: st.copyWith(clearWork: true),
                                      );
                                    }
                                    : null,
                          ),
                          for (final e in st.extras)
                            _QuickSheetRow(
                              icon: quickAddressIconDataForKey(e.iconKey),
                              title: e.tag,
                              subtitle: romagnaHitDisplayLine(e.hit),
                              onTap: () {
                                Navigator.pop(ctx);
                                _pickQuickSlot(
                                  slotTitle: e.tag,
                                  replaceExtra: e,
                                );
                              },
                              onRemove:
                                  () => _removeQuickAddressWithUndo(
                                    next: st.removeExtraById(e.id),
                                  ),
                            ),
                          if (st.canAddMore &&
                              st.extras.length < QuickAddressesState.kMaxExtras)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.add_circle_outline_rounded,
                                color: kRomagnaPrimary,
                              ),
                              title: Text(
                                'Aggiungi indirizzo con nome…',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: kRomagnaPrimary,
                                ),
                              ),
                              onTap: () async {
                                final tag = await _promptCustomQuickTag(ctx);
                                if (tag == null || tag.isEmpty) return;
                                final iconKey = await _promptQuickAddressIcon(
                                  ctx,
                                  initialTag: tag,
                                );
                                if (iconKey == null) return;
                                if (!context.mounted) return;
                                Navigator.pop(ctx);
                                await _pickQuickSlot(
                                  slotTitle: tag,
                                  extraIconKey: iconKey,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _removeQuickAddressWithUndo({required QuickAddressesState next}) {
    final prev = _quickAddressNotifier.value;
    _setQuickAddresses(next);
    _showQuickAddressUndoOverlay(onUndo: () => _setQuickAddresses(prev));
  }

  void _dismissQuickUndoOverlay() {
    _quickUndoOverlayEntry?.remove();
    _quickUndoOverlayEntry = null;
  }

  void _showQuickAddressUndoOverlay({required VoidCallback onUndo}) {
    _dismissQuickUndoOverlay();
    final overlay = Overlay.of(context, rootOverlay: true);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder:
          (ctx) => Positioned(
            bottom: MediaQuery.of(ctx).padding.bottom + 86,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: kRomagnaDarkGray.withValues(alpha: 0.95),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.24),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Indirizzo rimosso',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: kRomagnaPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                _dismissQuickUndoOverlay();
                                onUndo();
                              },
                              child: Text(
                                'Annulla',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 3,
                        width: double.infinity,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 1, end: 0),
                          duration: const Duration(seconds: 5),
                          onEnd: () {
                            if (_quickUndoOverlayEntry == entry) {
                              _dismissQuickUndoOverlay();
                            }
                          },
                          builder:
                              (context, value, _) => Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: value,
                                  alignment: Alignment.centerLeft,
                                  child: ColoredBox(
                                    color: kRomagnaPrimary,
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
    _quickUndoOverlayEntry = entry;
    overlay.insert(entry);
  }

  Future<String?> _promptCustomQuickTag(BuildContext ctx) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: ctx,
      builder:
          (dctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text(
              'Nome indirizzo',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: kRomagnaDarkGray,
              ),
            ),
            content: TextField(
              controller: c,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Es. Hotel, Negozio, Palestra',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dctx),
                child: Text(
                  'Annulla',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
              FilledButton(
                onPressed: () {
                  final t = c.text.trim();
                  if (t.isEmpty || t == 'Casa' || t == 'Lavoro') return;
                  Navigator.pop(dctx, t);
                },
                child: Text(
                  'Continua',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  Future<String?> _promptQuickAddressIcon(
    BuildContext ctx, {
    required String initialTag,
  }) async {
    return showDialog<String>(
      context: ctx,
      builder: (_) => _QuickAddressIconPickerDialog(initialTag: initialTag),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ctrl = AppSettingsScope.of(context);
    if (!identical(ctrl, _settingsCtrl)) {
      _settingsCtrl?.removeListener(_onAppSettingsChanged);
      _settingsCtrl = ctrl;
      ctrl.addListener(_onAppSettingsChanged);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mapSearchFocusNode.addListener(_onMapSearchFocusChangedForRecenter);
    _busStopSheetLinesNotifier.addListener(
      _onBusStopSheetLinesChangedForAutoNearby,
    );
    _userPointNotifier.addListener(_onUserPointChangedForAutoNearby);
    _sheetScrollController.addListener(_onSheetScrollAtLowSnap);
    _mapLoadFuture = _prepareMapAsync();
    loadQuickAddressesFromPrefs().then((s) {
      if (mounted) _quickAddressNotifier.value = s;
    });
    // Dopo il primo frame: abbiamo ScaffoldMessenger e contesto stabile per dialog / SnackBar.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _bootstrapUserLocation(),
    );
  }

  Future<void> _prepareMapAsync() async {
    // Yield del thread UI prima di inizializzare la mappa pesante.
    await Future<void>.delayed(Duration.zero);
    final stops = await loadTransitStopsFromAssets();
    final ferryStops = await loadFerryStopsFromAsset();

    var lineeMap = <String, RomagnaLineaRow>{};
    try {
      final rows = await loadLineeCatalog();
      lineeMap = buildLineeByComposite(rows);
    } catch (e, st) {
      debugPrint('loadLineeCatalog: $e\n$st');
    }

    final cal = await ServiceCalendarIndex.load();
    final sched = await StopTransitScheduleIndex.load(
      calendar: cal.isUsable ? cal : null,
    );
    final schedFailed = sched.loadFailed;

    TransitiStopLinesIndex? transiti;
    try {
      transiti = await TransitiStopLinesIndex.load();
    } catch (e, st) {
      debugPrint('TransitiStopLinesIndex.load: $e\n$st');
      transiti = null;
    }
    final index = transiti ?? TransitiStopLinesIndex.empty();
    final extraNames = <String>{};
    for (final pin in stops) {
      if (index.stopHasExtraurbanLineInTransit(pin.stopName)) {
        extraNames.add(pin.stopName);
      }
    }
    if (mounted) {
      setState(() {
        _busStops = stops;
        _ferryStops = ferryStops;
        _transitiIndex = index;
        _transitiCatalogLoadFailed = transiti == null;
        _lineeByComposite = lineeMap;
        _scheduleIndex = sched;
        _scheduleLoadFailed = schedFailed;
        _extraurbanStopNames
          ..clear()
          ..addAll(extraNames);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _romagnaMapStateKey.currentState?.applyRasterKind(
          mapRasterForSettings(AppSettingsScope.of(context).value),
        );
        // Precarica planner Percorso mentre l'utente usa la mappa (cache condivisa).
        unawaited(PercorsoSearchService.load());
        unawaited(GraphHopperWalkService.instance.initialize());
      });
    }
  }

  /// Passo 1–2: verifica servizi GPS e permessi; eventualmente mostra dialog esplicativo prima del prompt di sistema.
  Future<void> _bootstrapUserLocation() async {
    if (!mounted) return;
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        _applyRomagnaFallback('GPS disattivato. Mappa centrata sulla Romagna.');
        return;
      }

      var permission = await Geolocator.checkPermission();

      // Web / browser senza Permission API: proviamo comunque la richiesta esplicita.
      if (permission == LocationPermission.unableToDetermine) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        await _showLocationBlockedDialog();
        if (!mounted) return;
        _applyRomagnaFallback(
          'Posizione bloccata nelle impostazioni. Vista Romagna.',
        );
        return;
      }

      if (permission == LocationPermission.denied) {
        final consent = await _showLocationRationaleDialog();
        if (!mounted) return;
        if (consent != true) {
          _applyRomagnaFallback('Posizione in tempo reale non disponibile.');
          return;
        }
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          _applyRomagnaFallback('Permesso negato. Mappa sulla Romagna.');
          return;
        }
      }

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _applyRomagnaFallback(
          'Posizione non disponibile. Mappa sulla Romagna.',
        );
        return;
      }

      // Passo 3: prima lettura GPS (timeout per evitare attese infinite).
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;

      final here = LatLng(pos.latitude, pos.longitude);
      if (!isValidMapLatLng(here)) {
        _applyRomagnaFallback('Coordinate GPS non valide. Vista Romagna.');
        return;
      }
      _initialLocationPresentationPending = true;
      _userPointNotifier.value = here;
      _searchPinNotifier.value = null;
      _searchBusStopHighlightNotifier.value = null;
      _mapSearchAddressHit = null;
      _startLivePositionStream();
      unawaited(_presentUserLocationOnMap(here, openingPresentation: true));
    } on LocationServiceDisabledException {
      _applyRomagnaFallback(
        'Servizi di localizzazione non disponibili. Vista Romagna.',
      );
    } on TimeoutException {
      _applyRomagnaFallback('Timeout lettura GPS. Vista Romagna.');
    } catch (e, st) {
      debugPrint('Localizzazione: $e\n$st');
      _applyRomagnaFallback(
        'Impossibile rilevare la posizione. Vista Romagna.',
      );
    }
  }

  /// Avvia lo stream geolocator: aggiorna solo il marker senza forzare il pan ad ogni tick (l’utente può spostare la mappa).
  void _startLivePositionStream() {
    _positionSubscription?.cancel();
    try {
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,
        ),
      ).listen((Position pos) {
        if (!mounted) return;
        final p = LatLng(pos.latitude, pos.longitude);
        if (!isValidMapLatLng(p)) return;
        _userPointNotifier.value = p;
      }, onError: (Object e) => debugPrint('Stream posizione: $e'));
    } catch (e, st) {
      debugPrint('Stream non avviato: $e\n$st');
    }
  }

  /// Centra di nuovo sulla posizione (FAB): rilegge GPS se i permessi sono già ok, altrimenti ripete il flusso guidato.
  Future<void> _recenterOnMyLocationPressed() async {
    if (!mounted) return;
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        _applyRomagnaFallback('GPS disattivato. Mappa sulla Romagna.');
        return;
      }

      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.whileInUse &&
          perm != LocationPermission.always) {
        await _bootstrapUserLocation();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      final here = LatLng(pos.latitude, pos.longitude);
      if (!isValidMapLatLng(here)) {
        if (mounted) _snackDiscreet('Coordinate non valide. Riprova.');
        return;
      }
      _userPointNotifier.value = here;
      _searchPinNotifier.value = null;
      _searchBusStopHighlightNotifier.value = null;
      _mapSearchAddressHit = null;
      if (_sheetIdleAfterPinDeselect) {
        setState(() => _sheetIdleAfterPinDeselect = false);
      }
      _startLivePositionStream();
      unawaited(_presentUserLocationOnMap(here, openingPresentation: false));
    } on TimeoutException {
      if (mounted) {
        _snackDiscreet('Lettura posizione in ritardo. Riprova tra poco.');
      }
    } catch (e, st) {
      debugPrint('FAB posizione: $e\n$st');
      if (mounted) _snackDiscreet('Impossibile aggiornare la posizione.');
    }
  }

  /// Dialog prima del prompt di sistema: spiega il perché in modo chiaro e rispettoso del rifiuto.
  Future<bool?> _showLocationRationaleDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Posizione',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: kRomagnaDarkGray,
            ),
          ),
          content: Text(
            'RomagnaGO usa la tua posizione solo mentre usi l’app, per centrare la mappa su di te e suggerirti fermate e percorsi nelle vicinanze.\n\n'
            'Puoi rifiutare: la mappa resterà sulla Romagna.',
            style: GoogleFonts.inter(
              height: 1.4,
              color: kRomagnaDarkGray.withValues(alpha: 0.85),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Non ora',
                style: GoogleFonts.inter(
                  color: kNavIconInactive,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kRomagnaPrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Consenti',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Permesso negato in modo permanente: offriamo apertura impostazioni (comportamento previsto su iOS/Android).
  Future<void> _showLocationBlockedDialog() {
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Posizione bloccata',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: kRomagnaDarkGray,
            ),
          ),
          content: Text(
            'Hai negato l’accesso alla posizione in modo permanente. Puoi abilitarlo dalle impostazioni di sistema per RomagnaGO.',
            style: GoogleFonts.inter(
              height: 1.4,
              color: kRomagnaDarkGray.withValues(alpha: 0.85),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Chiudi',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kRomagnaPrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await Geolocator.openAppSettings();
              },
              child: Text(
                'Impostazioni',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Fallback visivo: Romagna + niente marker; messaggio breve e discreto.
  void _applyRomagnaFallback(String message) {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    safeMapMove(_mapController, kRomagnaMapCenter, kRomagnaMapZoom);
    if (!mounted) return;
    _userPointNotifier.value = null;
    _searchPinNotifier.value = null;
    _searchBusStopHighlightNotifier.value = null;
    _mapSearchAddressHit = null;
    _busStopSheetLinesNotifier.value = null;
    _snackDiscreet(message);
  }

  /// SnackBar floating, tipografia Inter, tono grigio scuro (non invasivo).
  void _snackDiscreet(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.3,
            color: Colors.white,
          ),
        ),
        backgroundColor: kRomagnaDarkGray.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildNonMapTabBody() {
    if (_navIndex == 1) {
      return PercorsoPage(priorityOrigin: _userPointNotifier.value);
    }
    if (_navIndex == 2) {
      return const NavettePage();
    }
    if (_navIndex == 3) {
      return const _SectionPlaceholder(
        icon: Icons.event_note_rounded,
        title: 'Eventi',
        subtitle: 'Placeholder eventi in arrivo',
      );
    }
    return AltroMenuPage(
      settingsController: _settingsCtrl!,
      quickAddressesListenable: _quickAddressNotifier,
      onSettingsApply: _handleSettingsApply,
    );
  }

  Future<void> _handleSettingsApply(
    AppSettings settings,
    QuickAddressesState quickAddresses,
  ) async {
    await _settingsCtrl!.apply(settings);
    await saveQuickAddressesToPrefs(quickAddresses);
    if (!mounted) return;
    _quickAddressNotifier.value = quickAddresses;
    setState(() {});
    _romagnaMapStateKey.currentState?.applyRasterKind(
      mapRasterForSettings(settings),
    );
  }

  void _onAppSettingsChanged() {
    if (!mounted) return;
    setState(() {});
    final s = _settingsCtrl!.value;
    _romagnaMapStateKey.currentState?.applyRasterKind(mapRasterForSettings(s));
  }

  @override
  void dispose() {
    _settingsCtrl?.removeListener(_onAppSettingsChanged);
    _dismissQuickUndoOverlay();
    _recenterStopLayoutTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _mapSearchFocusNode.removeListener(_onMapSearchFocusChangedForRecenter);
    _busStopSheetLinesNotifier.removeListener(
      _onBusStopSheetLinesChangedForAutoNearby,
    );
    _userPointNotifier.removeListener(_onUserPointChangedForAutoNearby);
    _positionSubscription?.cancel();
    _mapController.dispose();
    _userPointNotifier.dispose();
    _searchPinNotifier.dispose();
    _searchBusStopHighlightNotifier.dispose();
    _busStopSheetLinesNotifier.dispose();
    _quickAddressNotifier.dispose();
    _mapSearchFocusNode.dispose();
    _mapSearchDismissTick.dispose();
    _searchController.dispose();
    _sheetScrollController.removeListener(_onSheetScrollAtLowSnap);
    _sheetScrollController.dispose();
    super.dispose();
  }

  void _resetSheetScrollToTop() {
    if (_sheetScrollController.hasClients) {
      _sheetScrollController.jumpTo(0);
    }
  }

  void _onSheetScrollAtLowSnap() {
    final h = _mapStackHeightCache;
    if (h <= 0) return;
    final snapLow = (kSheetSnapLowPx / h).clamp(0.07, 0.22);
    if (!_sheetIsAtLowSnap(_sheetExtent, snapLow)) return;
    if (!_sheetScrollController.hasClients) return;
    if (_sheetScrollController.offset > 0.5) {
      _sheetScrollController.jumpTo(0);
    }
  }

  void _snapSheetExtentToNearest(_SheetSnapGeom g) {
    final targets = [g.low, g.half, g.full];
    var best = targets.first;
    for (final t in targets) {
      if ((_sheetExtent - t).abs() < (_sheetExtent - best).abs()) {
        best = t;
      }
    }
    setState(() => _sheetExtent = best);
    if (_sheetIsAtLowSnap(best, g.low)) {
      _resetSheetScrollToTop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(seconds: 1),
      curve: Curves.easeOutCubic,
      builder:
          (context, opacity, child) => Opacity(opacity: opacity, child: child),
      child: Scaffold(
        backgroundColor: kMapBase,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _navIndex,
          onDestinationSelected: (i) {
            _dismissMapSearchBar();
            setState(() => _navIndex = i);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Mappa',
            ),
            NavigationDestination(
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route),
              label: 'Percorso',
            ),
            NavigationDestination(
              icon: Icon(Icons.airport_shuttle_outlined),
              selectedIcon: Icon(Icons.airport_shuttle),
              label: 'Navette',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_outlined),
              selectedIcon: Icon(Icons.event),
              label: 'Eventi',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_outlined),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'Altro',
            ),
          ],
        ),
        body:
            _navIndex == 0
                ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Obbligatorio [Positioned.fill]: un [LayoutBuilder] diretto nello Stack
                    // ha altezza non limitata e può collassare (mappa grigia) con la tastiera.
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final h = constraints.maxHeight;
                          _mapStackHeightCache = h;
                          if (_initialLocationPresentationPending) {
                            final pending = _userPointNotifier.value;
                            if (pending != null && isValidMapLatLng(pending)) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                unawaited(
                                  _presentUserLocationOnMap(
                                    pending,
                                    openingPresentation: true,
                                  ),
                                );
                              });
                            }
                          }
                          final mq = MediaQuery.of(context);
                          final g = _sheetSnapGeom(mq, h);
                          final snapLow = g.low;
                          final snapFull = g.full;
                          final extent = _sheetExtent.clamp(snapLow, snapFull);
                          final sheetScrollLocked = _sheetIsAtLowSnap(
                            extent,
                            snapLow,
                          );

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: FutureBuilder<void>(
                                  future: _mapLoadFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState !=
                                        ConnectionState.done) {
                                      return const ColoredBox(
                                        color: kMapBase,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                          ),
                                        ),
                                      );
                                    }
                                    return _RomagnaMap(
                                      key: _romagnaMapStateKey,
                                      mapController: _mapController,
                                      userPointListenable: _userPointNotifier,
                                      searchPinListenable: _searchPinNotifier,
                                      searchBusStopHighlightListenable:
                                          _searchBusStopHighlightNotifier,
                                      quickAddressListenable:
                                          _quickAddressNotifier,
                                      busStops: _visibleBusStops,
                                      ferryStops: _visibleFerryStops,
                                      transitiIndex: _transitiIndex,
                                      transitiCatalogLoadFailed:
                                          _transitiCatalogLoadFailed,
                                      scheduleIndex: _scheduleIndex,
                                      scheduleLoadFailed: _scheduleLoadFailed,
                                      lineeByComposite: _lineeByComposite,
                                      sheetExtent: extent,
                                      sheetDraggedByUser:
                                          _sheetDragByUserInProgress,
                                      mapStackHeight: h,
                                      mapFabBottomPx: h * extent + 8,
                                      busStopSheetLinesNotifier:
                                          _busStopSheetLinesNotifier,
                                      onClearSearchBusStopHighlight:
                                          () =>
                                              _searchBusStopHighlightNotifier
                                                  .value = null,
                                      onSearchPinLongPressClear:
                                          _clearSearchPinOnly,
                                      onSearchPinTap: _onMapSearchPinTapped,
                                      onQuickAddressTap:
                                          _showQuickAddressInBottomSheet,
                                      onUserPointTap:
                                          _recenterOnMyLocationPressed,
                                      onMapBlankTap: _handleRomagnaMapBlankTap,
                                    );
                                  },
                                ),
                              ),
                              ListenableBuilder(
                                listenable: _mapSearchFocusNode,
                                builder: (context, _) {
                                  if (_mapSearchFocusNode.hasFocus) {
                                    return const SizedBox.shrink();
                                  }
                                  return Positioned.fill(
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom: 0,
                                          height: h * extent,
                                          child: Material(
                                            color: Colors.white,
                                            elevation: 12,
                                            shadowColor: Colors.black26,
                                            shape: const RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                    top: Radius.circular(28),
                                                  ),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                GestureDetector(
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  onVerticalDragUpdate: (
                                                    details,
                                                  ) {
                                                    final wasLow =
                                                        _sheetIsAtLowSnap(
                                                          _sheetExtent,
                                                          snapLow,
                                                        );
                                                    setState(() {
                                                      _sheetDragByUserInProgress =
                                                          true;
                                                      final next = (_sheetExtent -
                                                              details.delta.dy /
                                                                  h)
                                                          .clamp(
                                                            snapLow,
                                                            snapFull,
                                                          );
                                                      _sheetExtent = next;
                                                    });
                                                    if (!wasLow &&
                                                        _sheetIsAtLowSnap(
                                                          _sheetExtent,
                                                          snapLow,
                                                        )) {
                                                      _resetSheetScrollToTop();
                                                    }
                                                  },
                                                  onVerticalDragEnd: (_) {
                                                    setState(() {
                                                      _sheetDragByUserInProgress =
                                                          false;
                                                    });
                                                    _snapSheetExtentToNearest(
                                                      g,
                                                    );
                                                  },
                                                  child: SizedBox(
                                                    height:
                                                        kSheetSnapDragStripPx,
                                                    child: Center(
                                                      child: Container(
                                                        width: 40,
                                                        height: 4,
                                                        decoration: BoxDecoration(
                                                          color: kSheetHandle,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                999,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: _RomagnaBottomSheet(
                                                    scrollController:
                                                        _sheetScrollController,
                                                    scrollLocked:
                                                        sheetScrollLocked,
                                                    selectedFilterIndex:
                                                        _sheetFilterIndex,
                                                    onFilterSelected:
                                                        (i) => setState(
                                                          () =>
                                                              _sheetFilterIndex =
                                                                  i,
                                                        ),
                                                    busStopSheetLines:
                                                        _busStopSheetLinesNotifier,
                                                    scheduleIndex:
                                                        _scheduleIndex,
                                                    lineeByComposite:
                                                        _lineeByComposite,
                                                    onQuickAddressEdit:
                                                        _pickQuickSlotFromMarkerDetail,
                                                    onQuickAddressRemove:
                                                        _removeQuickAddressFromMarkerDetail,
                                                    onQuickAddressNearbyStopSelected: (
                                                      pin,
                                                    ) {
                                                      _romagnaMapStateKey
                                                          .currentState
                                                          ?.selectBusStopFromSearch(
                                                            pin,
                                                          );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 16,
                                          bottom: h * extent + 8,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _MapZoomButton(
                                                icon: Icons.add,
                                                onTap: () {
                                                  try {
                                                    final cam =
                                                        _mapController.camera;
                                                    if (!cam.zoom.isFinite) {
                                                      safeMapMove(
                                                        _mapController,
                                                        kRomagnaMapCenter,
                                                        kRomagnaMapZoom,
                                                      );
                                                      return;
                                                    }
                                                    final z = (cam.zoom + 1)
                                                        .clamp(
                                                          kRomagnaMapMinZoom,
                                                          kRomagnaMapMaxZoom,
                                                        );
                                                    safeMapMove(
                                                      _mapController,
                                                      cam.center,
                                                      z,
                                                    );
                                                  } catch (_) {
                                                    safeMapMove(
                                                      _mapController,
                                                      kRomagnaMapCenter,
                                                      kRomagnaMapZoom,
                                                    );
                                                  }
                                                },
                                              ),
                                              const SizedBox(height: 8),
                                              _MapZoomButton(
                                                icon: Icons.remove,
                                                onTap: () {
                                                  try {
                                                    final cam =
                                                        _mapController.camera;
                                                    if (!cam.zoom.isFinite) {
                                                      safeMapMove(
                                                        _mapController,
                                                        kRomagnaMapCenter,
                                                        kRomagnaMapZoom,
                                                      );
                                                      return;
                                                    }
                                                    final z = (cam.zoom - 1)
                                                        .clamp(
                                                          kRomagnaMapMinZoom,
                                                          kRomagnaMapMaxZoom,
                                                        );
                                                    safeMapMove(
                                                      _mapController,
                                                      cam.center,
                                                      z,
                                                    );
                                                  } catch (_) {
                                                    safeMapMove(
                                                      _mapController,
                                                      kRomagnaMapCenter,
                                                      kRomagnaMapZoom,
                                                    );
                                                  }
                                                },
                                              ),
                                              const SizedBox(height: 12),
                                              _MapCircularControl(
                                                onTap:
                                                    _recenterOnMyLocationPressed,
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                child: Icon(
                                                  Icons.my_location,
                                                  color: kRomagnaPrimary,
                                                  size: 22,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _MapSearchBar(
                                mapController: _mapController,
                                controller: _searchController,
                                searchFocusNode: _mapSearchFocusNode,
                                dismissRequests: _mapSearchDismissTick,
                                minSearchChars: _minSearchChars,
                                transitStops: _visibleBusStops,
                                ferryStops: _visibleFerryStops,
                                maxTransitStops: _settings.mapSearchMaxResults,
                                sortStopsByDistance:
                                    _settings.priorityNearbyStopsInSearch,
                                searchPinListenable: _searchPinNotifier,
                                searchBusStopHighlightNotifier:
                                    _searchBusStopHighlightNotifier,
                                priorityOriginResolver: _searchPriorityOrigin,
                                onClearSearchAndPins:
                                    _clearMapSearchFieldAndPins,
                                onSearchResultChosen: (hit) {
                                  if (!isValidMapLatLng(hit.point)) {
                                    return;
                                  }
                                  if (hit.isFerryStop) {
                                    _searchPinNotifier.value = null;
                                    _mapSearchAddressHit = null;
                                    _searchBusStopHighlightNotifier.value =
                                        null;
                                    final ferry = ferryStopPinForSearchHit(
                                      hit,
                                      _ferryStops,
                                    );
                                    if (ferry != null) {
                                      _romagnaMapStateKey.currentState
                                          ?.selectFerryStopFromSearch(ferry);
                                      if (_sheetFilterIndex != 0) {
                                        setState(() => _sheetFilterIndex = 0);
                                      }
                                    }
                                  } else if (hit.isBusStop) {
                                    _searchPinNotifier.value = null;
                                    _mapSearchAddressHit = null;
                                    _searchBusStopHighlightNotifier.value =
                                        null;
                                    final pin = transitStopPinForSearchHit(
                                      hit,
                                      _busStops,
                                    );
                                    if (pin != null) {
                                      _romagnaMapStateKey.currentState
                                          ?.selectBusStopFromSearch(pin);
                                      if (_sheetFilterIndex != 0) {
                                        setState(() => _sheetFilterIndex = 0);
                                      }
                                    }
                                  } else {
                                    _searchBusStopHighlightNotifier.value =
                                        null;
                                    _mapSearchAddressHit = hit;
                                    _searchPinNotifier.value = hit.point;
                                    _showSearchAddressNearbyInBottomSheet(hit);
                                    _expandSheetToHalfIfCollapsed();
                                    _scheduleCenterSearchAddressPin(hit.point);
                                    if (_sheetFilterIndex != 0) {
                                      setState(() => _sheetFilterIndex = 0);
                                    }
                                  }
                                },
                              ),
                              ClipRect(
                                child: ListenableBuilder(
                                  listenable: _mapSearchFocusNode,
                                  builder: (context, _) {
                                    return AnimatedSlide(
                                      duration: const Duration(
                                        milliseconds: 340,
                                      ),
                                      curve: Curves.easeInOutCubic,
                                      offset:
                                          _mapSearchFocusNode.hasFocus
                                              ? const Offset(0, -1.85)
                                              : Offset.zero,
                                      child: IgnorePointer(
                                        ignoring: _mapSearchFocusNode.hasFocus,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 10,
                                          ),
                                          child: Row(
                                            children: [
                                              _IndirizziRapidiPill(
                                                onTap:
                                                    () =>
                                                        _openIndirizziRapidiSheet(),
                                              ),
                                              const Spacer(),
                                              _BigliettoPill(
                                                onTap:
                                                    () =>
                                                        _openBiglietto(context),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
                : _buildNonMapTabBody(),
      ),
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFAFAFA),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 52,
                color: kRomagnaPrimary.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: kRomagnaDarkGray,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.35,
                  color: kRomagnaDarkGray.withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Mappa: FlutterMap + Carto Positron + cerchio utente (azzurro #38b6ff, bordo bianco).
// -----------------------------------------------------------------------------
class _RomagnaMap extends StatefulWidget {
  const _RomagnaMap({
    super.key,
    required this.mapController,
    required this.userPointListenable,
    required this.searchPinListenable,
    required this.searchBusStopHighlightListenable,
    required this.quickAddressListenable,
    required this.busStops,
    required this.ferryStops,
    required this.transitiIndex,
    required this.transitiCatalogLoadFailed,
    required this.scheduleIndex,
    required this.scheduleLoadFailed,
    required this.lineeByComposite,
    required this.sheetExtent,
    required this.sheetDraggedByUser,
    required this.mapStackHeight,
    required this.mapFabBottomPx,
    required this.busStopSheetLinesNotifier,
    required this.onClearSearchBusStopHighlight,
    required this.onSearchPinLongPressClear,
    required this.onSearchPinTap,
    required this.onQuickAddressTap,
    required this.onUserPointTap,
    required this.onMapBlankTap,
  });

  final MapController mapController;

  final ValueListenable<LatLng?> userPointListenable;
  final ValueListenable<LatLng?> searchPinListenable;
  final ValueListenable<LatLng?> searchBusStopHighlightListenable;
  final ValueListenable<QuickAddressesState> quickAddressListenable;
  final List<TransitStopPin> busStops;
  final List<FerryStopPin> ferryStops;
  final TransitiStopLinesIndex transitiIndex;
  final bool transitiCatalogLoadFailed;
  final StopTransitScheduleIndex scheduleIndex;
  final bool scheduleLoadFailed;
  final Map<String, RomagnaLineaRow> lineeByComposite;

  /// Altezza foglio inferiore come frazione dello stack mappa (0–1).
  final double sheetExtent;
  final bool sheetDraggedByUser;

  /// Altezza dell’area mappa ([LayoutBuilder.maxHeight]): stesso `h` dei FAB a destra.
  final double mapStackHeight;

  /// Distanza dal fondo dell’area mappa al bordo inferiore dei FAB (uguale a `h*extent+8` in home).
  final double mapFabBottomPx;

  final ValueNotifier<BusStopSheetLinesPayload?> busStopSheetLinesNotifier;
  final VoidCallback onClearSearchBusStopHighlight;
  final VoidCallback onSearchPinLongPressClear;
  final VoidCallback onSearchPinTap;
  final ValueChanged<QuickAddressMarkerTapDetails> onQuickAddressTap;
  final VoidCallback onUserPointTap;
  final VoidCallback onMapBlankTap;

  @override
  State<_RomagnaMap> createState() => _RomagnaMapState();
}

class _RomagnaMapState extends State<_RomagnaMap> {
  /// Aggiorna solo overlay/marker che leggono [MapCamera], senza ricostruire
  /// [TileLayer] a ogni pinch/pan (evita tile sfocati che restano a lungo).
  final ValueNotifier<int> _mapCameraTick = ValueNotifier<int>(0);

  TransitStopPin? _selectedBusStop;
  FerryStopPin? _selectedFerryStop;
  String? _busStopPlaceLine;
  bool _busStopPlaceLoading = false;
  RomagnaMapRasterKind _rasterKind = RomagnaMapRasterKind.humanitarianHot;

  void applyRasterKind(RomagnaMapRasterKind kind) {
    if (_rasterKind == kind) return;
    setState(() => _rasterKind = kind);
  }

  static const double _kStopsShowMinZoom = 11.2;

  /// Da questo zoom in su: pinpoint con icona bus (sotto: solo pallino arancio).
  static const double _kStopsFullPinZoom = 14.0;

  bool hasSelectedMapPinpoint() =>
      _selectedBusStop != null || _selectedFerryStop != null;

  /// Tap su area mappa senza marker: deseleziona fermata/traghetto (il parent azzera ricerca e foglio).
  void clearMapSelectionsForBlankTap() {
    _clearBusStopSelection();
    _clearFerrySelection();
  }

  @override
  void dispose() {
    _mapCameraTick.dispose();
    super.dispose();
  }

  LatLng? _activeSearchPinPoint() {
    return widget.searchPinListenable.value;
  }

  @override
  void didUpdateWidget(covariant _RomagnaMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.sheetExtent - widget.sheetExtent).abs() > 0.015) {
      if (widget.sheetDraggedByUser) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final searchPin = _activeSearchPinPoint();
        if (searchPin != null &&
            isValidMapLatLng(searchPin) &&
            _selectedBusStop == null &&
            _selectedFerryStop == null) {
          centerSearchAddressPin(searchPin);
          return;
        }
        if (!_hasActiveMapContentToRecenter()) return;
        recenterForVisibleMapContent();
      });
    }
  }

  bool _hasActiveMapContentToRecenter() {
    if (_selectedBusStop != null || _selectedFerryStop != null) return true;
    final quick = widget.busStopSheetLinesNotifier.value?.quickAddressDetail;
    return quick != null && isValidMapLatLng(quick.hit.point);
  }

  /// Centro del punto selezionato nella fascia mappa visibile (sotto ricerca, sopra tendina).
  void centerPointInVisibleBand(
    LatLng point, {
    double zoom = kRomagnaMapMaxZoom,
    double visualAnchorOffsetPx = 0,
  }) {
    if (!isValidMapLatLng(point)) return;
    final mq = MediaQuery.of(context);
    final h = widget.mapStackHeight;
    if (h <= 0) return;

    final targetY = _verticalCenterVisibleMapBand(mq, h);
    final screenMidY = h * 0.5;
    final offsetDy = targetY + visualAnchorOffsetPx - screenMidY;

    safeMapMove(widget.mapController, point, zoom, offset: Offset(0, offsetDy));
  }

  /// Ricalcola centro nella fascia visibile per la selezione corrente oppure la posizione utente.
  void recenterForVisibleMapContent() {
    if (!mounted) return;
    final bus = _selectedBusStop;
    if (bus != null) {
      _centerMapOnStopPinAndCard(context, bus);
      return;
    }
    final ferry = _selectedFerryStop;
    if (ferry != null) {
      _centerMapOnFerryPinAndCard(context, ferry);
      return;
    }
    final quick = widget.busStopSheetLinesNotifier.value?.quickAddressDetail;
    if (quick != null && isValidMapLatLng(quick.hit.point)) {
      centerPointInVisibleBand(quick.hit.point, zoom: kQuickAddressZoom);
    }
  }

  void _onBusStopMarkerTap(TransitStopPin pin) {
    widget.onClearSearchBusStopHighlight();
    _selectedFerryStop = null;
    final sid = pin.stopId.trim();
    final basin = pin.basin.trim().toLowerCase();
    if (sid.isNotEmpty && (basin == 'fc' || basin == 'ra' || basin == 'rn')) {
      infobusPrefetchArrivalsForStop(basinLower: basin, palina: sid);
    }
    final bubbles =
        sid.isEmpty
            ? <StopTransitLineBubble>[]
            : buildStopTransitLineBubbles(
              rawStopId: sid,
              schedule: widget.scheduleIndex,
              lineeByComposite: widget.lineeByComposite,
              requireServiceOnCalendarDay: false,
            );
    widget.busStopSheetLinesNotifier.value = BusStopSheetLinesPayload(
      stopId: sid.isEmpty ? null : sid,
      stopNameRaw: pin.stopName,
      basinLower:
          pin.basin.trim().isEmpty ? null : pin.basin.trim().toLowerCase(),
      bubbles: bubbles,
      catalogLoadFailed: widget.transitiCatalogLoadFailed,
      scheduleLoadFailed: widget.scheduleLoadFailed,
    );
    setState(() {
      _selectedBusStop = pin;
      _busStopPlaceLine = pin.comune.isNotEmpty ? pin.comune : null;
      _busStopPlaceLoading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedBusStop != pin) return;
      _centerMapOnStopPinAndCard(context, pin);
    });
  }

  /// Stessa logica altezze della card sopra il pinpoint ([_busStopPopupOverlay]).
  double _stopCardStackAbovePinPx(TransitStopPin pin) {
    const tailH = 8.0;
    const markerRadius = 13.0;
    final stopNameUi = transitStopNameForDisplay(pin.stopName);
    final isLongName = stopNameUi.length > 24;
    final placeText = _busStopPlaceLine ?? 'Località non disponibile';
    final isLongPlace = !_busStopPlaceLoading && placeText.length > 30;
    final hasCode = pin.stopId.isNotEmpty;
    final hasDisabili = pin.disabili == 'yes' || pin.disabili == 'no';
    final zoneCode = _extractZoneCode(pin.zona);
    final hasZona = zoneCode != null;
    final showExtraurbanE =
        pin.stopId.trim().isNotEmpty
            ? widget.scheduleIndex.stopHasExtraurbanLine(
              rawStopId: pin.stopId,
              lineeByComposite: widget.lineeByComposite,
            )
            : widget.transitiIndex.stopHasExtraurbanLineInTransit(pin.stopName);
    final baseCardH =
        hasCode
            ? (isLongName || isLongPlace ? 124.0 : 112.0)
            : (isLongName || isLongPlace ? 110.0 : 98.0);
    final hasLongText = isLongName || isLongPlace;
    final iconSectionExtraHeight =
        (hasDisabili || hasZona || showExtraurbanE)
            ? (hasLongText ? 30.0 : 16.0)
            : 0.0;
    final minCardH = baseCardH + iconSectionExtraHeight;
    return minCardH + tailH + markerRadius;
  }

  /// Centro verticale (coordinate [0..h] nel widget mappa) della fascia effettivamente visibile:
  /// sotto barra ricerca e sopra il foglio inferiore, usando l’extent foglio coerente col payload.
  double _verticalCenterVisibleMapBand(MediaQueryData mq, double h) {
    if (h <= 0) return h * 0.5;
    final g = _sheetSnapGeom(mq, h);
    final extentUsed = widget.sheetExtent.clamp(g.low, g.full);
    final sheetTopY = h * (1.0 - extentUsed);
    // La mappa è full-bleed sotto la pill ricerca (overlay nello Stack home).
    final visibleTop = (mq.padding.top + kMapSearchChromeTopPx).clamp(
      0.0,
      math.max(0.0, sheetTopY - 40),
    );
    return visibleTop + (sheetTopY - visibleTop) * 0.5;
  }

  EdgeInsets _visibleMapBandPadding(
    MediaQueryData mq,
    double mapHeight, {
    required double sheetExtentFraction,
  }) {
    final g = _sheetSnapGeom(mq, mapHeight);
    final extent = sheetExtentFraction.clamp(g.low, g.full);
    return EdgeInsets.fromLTRB(
      12,
      mq.padding.top + kMapSearchChromeTopPx,
      12,
      mapHeight * extent,
    );
  }

  /// Centra il pin azzurro nella fascia mappa visibile sopra la tendina alzata.
  void centerSearchAddressPin(LatLng point, {double zoom = kSearchResultZoom}) {
    if (!isValidMapLatLng(point)) return;
    final mq = MediaQuery.of(context);
    final h = widget.mapStackHeight;
    if (h <= 0) return;

    final g = _sheetSnapGeom(mq, h);
    final sheetFraction = widget.sheetExtent.clamp(g.low, g.full);
    final padding = _visibleMapBandPadding(
      mq,
      h,
      sheetExtentFraction: sheetFraction,
    );

    final fitted = widget.mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: [point],
        padding: padding,
        maxZoom: zoom,
        minZoom: zoom,
      ),
    );

    if (fitted) return;

    // Fallback: offset verso il centro della fascia (sopra metà schermo).
    final topPad = padding.top;
    final bottomPad = padding.bottom;
    final targetY = topPad + (h - topPad - bottomPad) * 0.5;
    final offsetDy = targetY - h * 0.5;
    safeMapMove(widget.mapController, point, zoom, offset: Offset(0, offsetDy));
  }

  /// Porta pinpoint + card al centro della fascia mappa visibile e zoom massimo.
  void _centerMapOnStopPinAndCard(BuildContext context, TransitStopPin pin) {
    if (!isValidMapLatLng(pin.point)) return;
    centerPointInVisibleBand(
      pin.point,
      visualAnchorOffsetPx: _stopCardStackAbovePinPx(pin) * 0.5,
    );
  }

  /// Ricalcola centro/zoom dopo cambio altezza area mappa (es. chiusura tastiera).
  void recenterSelectedPinForSheetLayout() {
    recenterForVisibleMapContent();
  }

  /// Stessa logica del tap sul pinpoint (card + linee nel foglio), es. da ricerca.
  void selectBusStopFromSearch(TransitStopPin pin) {
    _onBusStopMarkerTap(pin);
  }

  void selectFerryStopFromSearch(FerryStopPin ferry) {
    _onFerryStopMarkerTap(ferry);
  }

  void _clearBusStopSelection() {
    if (_selectedBusStop == null &&
        !_busStopPlaceLoading &&
        widget.busStopSheetLinesNotifier.value == null) {
      return;
    }
    widget.busStopSheetLinesNotifier.value = null;
    setState(() {
      _selectedBusStop = null;
      _busStopPlaceLine = null;
      _busStopPlaceLoading = false;
    });
  }

  void _clearFerrySelection() {
    if (_selectedFerryStop == null) return;
    if (widget.busStopSheetLinesNotifier.value?.isFerry ?? false) {
      widget.busStopSheetLinesNotifier.value = null;
    }
    setState(() => _selectedFerryStop = null);
  }

  void _onFerryStopMarkerTap(FerryStopPin ferry) {
    widget.onClearSearchBusStopHighlight();
    widget.busStopSheetLinesNotifier.value = BusStopSheetLinesPayload(
      stopNameRaw: ferry.stopName,
      isFerry: true,
      ferryComuneProvincia: '${ferry.comune} (${ferry.provincia})',
      bubbles: const <StopTransitLineBubble>[],
      catalogLoadFailed: false,
      scheduleLoadFailed: false,
    );
    setState(() {
      _selectedBusStop = null;
      _busStopPlaceLine = null;
      _busStopPlaceLoading = false;
      _selectedFerryStop = ferry;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedFerryStop?.id != ferry.id) return;
      _centerMapOnFerryPinAndCard(context, ferry);
    });
  }

  double _ferryCardStackAbovePinPx(FerryStopPin ferry) {
    const tailH = 8.0;
    const markerRadius = 13.0;
    const minCardH = 98.0;
    return minCardH + tailH + markerRadius;
  }

  void _centerMapOnFerryPinAndCard(BuildContext context, FerryStopPin ferry) {
    if (!isValidMapLatLng(ferry.point)) return;
    centerPointInVisibleBand(
      ferry.point,
      visualAnchorOffsetPx: _ferryCardStackAbovePinPx(ferry) * 0.5,
    );
  }

  /// Dimensione icona bus nel pinpoint: cresce con lo zoom (dal passaggio pallino → pin).
  double _stopIconSizeForZoom(double zoom) {
    final span = kRomagnaMapMaxZoom - _kStopsFullPinZoom;
    if (span <= 0) return 13;
    final t = ((zoom - _kStopsFullPinZoom) / span).clamp(0.0, 1.0);
    return 10.5 + t * 6.5;
  }

  /// Pallino anteprima (arancio + bordo bianco): leggermente più grande avvicinandosi al pin completo.
  double _stopPreviewDotDiameter(double zoom) {
    final span = _kStopsFullPinZoom - _kStopsShowMinZoom;
    if (span <= 0) return 8;
    final t = ((zoom - _kStopsShowMinZoom) / span).clamp(0.0, 1.0);
    return 6.5 + t * 3.5;
  }

  bool _isMetromarePin(TransitStopPin pin) =>
      pin.stopId.trim().toUpperCase().startsWith('TRC');

  @override
  Widget build(BuildContext context) {
    final tileSpec = _rasterTileSpec(_rasterKind);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(
            initialCenter: kRomagnaMapCenter,
            initialZoom: kRomagnaMapZoom,
            minZoom: kRomagnaMapMinZoom,
            maxZoom: kRomagnaMapMaxZoom,
            backgroundColor: _mapRasterBackground(_rasterKind),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onPositionChanged: (_, _) {
              _mapCameraTick.value++;
            },
            onTap: (_, __) {
              widget.onMapBlankTap();
            },
          ),
          children: [
            TileLayer(
              key: ValueKey<RomagnaMapRasterKind>(_rasterKind),
              urlTemplate: tileSpec.urlTemplate,
              subdomains: tileSpec.subdomains,
              userAgentPackageName: 'RomagnaGO',
              maxNativeZoom: tileSpec.maxNativeZoom,
            ),
            ValueListenableBuilder<LatLng?>(
              valueListenable: widget.userPointListenable,
              builder: (context, userPoint, _) {
                if (userPoint == null || !isValidMapLatLng(userPoint)) {
                  return const SizedBox.shrink();
                }
                return MarkerLayer(
                  markers: [
                    Marker(
                      point: userPoint,
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onUserPointTap,
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: kRomagnaPrimary.withValues(alpha: 0.42),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            ValueListenableBuilder<LatLng?>(
              valueListenable: widget.searchPinListenable,
              builder: (context, searchPinPoint, _) {
                if (searchPinPoint == null ||
                    !isValidMapLatLng(searchPinPoint)) {
                  return const SizedBox.shrink();
                }
                return MarkerLayer(
                  markers: [
                    Marker(
                      point: searchPinPoint,
                      width: 48,
                      height: 52,
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onSearchPinTap,
                        onLongPress: widget.onSearchPinLongPressClear,
                        child: SizedBox(
                          width: 48,
                          height: 52,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Icon(
                              Icons.location_on_rounded,
                              size: 48,
                              color: kRomagnaPrimary,
                              shadows: const [],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            ValueListenableBuilder<QuickAddressesState>(
              valueListenable: widget.quickAddressListenable,
              builder: (context, quickAddressState, _) {
                final markers = <Marker>[];

                void addMarker(QuickAddressMarkerTapDetails details) {
                  final hit = details.hit;
                  if (!isValidMapLatLng(hit.point)) return;
                  markers.add(
                    Marker(
                      point: hit.point,
                      width: 44,
                      height: 48,
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        onTap: () => widget.onQuickAddressTap(details),
                        child: Material(
                          elevation: 2,
                          shadowColor: Colors.black26,
                          shape: const CircleBorder(),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: Icon(
                              details.icon,
                              size: 22,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final h = quickAddressState.home;
                if (h != null) {
                  addMarker(
                    QuickAddressMarkerTapDetails(
                      title: 'Casa',
                      icon: Icons.home_rounded,
                      hit: h,
                      slotKind: QuickAddressSlotKind.home,
                    ),
                  );
                }
                final w = quickAddressState.work;
                if (w != null) {
                  addMarker(
                    QuickAddressMarkerTapDetails(
                      title: 'Lavoro',
                      icon: Icons.work_outline_rounded,
                      hit: w,
                      slotKind: QuickAddressSlotKind.work,
                    ),
                  );
                }
                for (final e in quickAddressState.extras) {
                  addMarker(
                    QuickAddressMarkerTapDetails(
                      title: e.tag,
                      icon: quickAddressIconDataForKey(e.iconKey),
                      hit: e.hit,
                      slotKind: QuickAddressSlotKind.extra,
                      namedExtra: e,
                    ),
                  );
                }
                if (markers.isEmpty) return const SizedBox.shrink();
                return MarkerLayer(markers: markers);
              },
            ),
            if (widget.ferryStops.isNotEmpty)
              ValueListenableBuilder<int>(
                valueListenable: _mapCameraTick,
                builder: (context, _, __) {
                  final cam = widget.mapController.camera;
                  final zoom = cam.zoom.isFinite ? cam.zoom : kRomagnaMapZoom;
                  if (zoom < _kStopsShowMinZoom) return const SizedBox.shrink();
                  final bounds = cam.visibleBounds;
                  if (zoom < _kStopsFullPinZoom) {
                    final dotD = _stopPreviewDotDiameter(zoom);
                    final borderW = (dotD * 0.2).clamp(1.0, 2.0);
                    return MarkerLayer(
                      markers: [
                        for (final ferry in widget.ferryStops)
                          if (bounds.contains(ferry.point))
                            Marker(
                              point: ferry.point,
                              width: dotD + 8,
                              height: dotD + 8,
                              alignment: Alignment.center,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _onFerryStopMarkerTap(ferry),
                                child: Center(
                                  child: Container(
                                    width: dotD,
                                    height: dotD,
                                    decoration: BoxDecoration(
                                      color:
                                          _selectedFerryStop?.id == ferry.id
                                              ? kFerrySelectedDarkYellow
                                              : kFerryElectricBlue,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: borderW,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x33000000),
                                          blurRadius: 3,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    );
                  }

                  final iconSize = _stopIconSizeForZoom(zoom);
                  final markerPad = 5.0 + (zoom - _kStopsFullPinZoom) * 0.4;
                  final markerSize = iconSize + 2 * markerPad;
                  return MarkerLayer(
                    markers: [
                      for (final ferry in widget.ferryStops)
                        if (bounds.contains(ferry.point))
                          Marker(
                            point: ferry.point,
                            width: markerSize,
                            height: markerSize + 2,
                            alignment: Alignment.bottomCenter,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _onFerryStopMarkerTap(ferry),
                              child: Material(
                                elevation:
                                    _selectedFerryStop?.id == ferry.id ? 3 : 1,
                                shadowColor:
                                    _selectedFerryStop?.id == ferry.id
                                        ? Colors.black38
                                        : Colors.black26,
                                shape: const CircleBorder(),
                                color:
                                    _selectedFerryStop?.id == ferry.id
                                        ? kFerrySelectedDarkYellow
                                        : kFerryElectricBlue,
                                child: Padding(
                                  padding: const EdgeInsets.all(2.5),
                                  child: Icon(
                                    Icons.directions_boat_filled_rounded,
                                    size: iconSize,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ],
                  );
                },
              ),
            if (widget.busStops.isNotEmpty)
              ValueListenableBuilder<int>(
                valueListenable: _mapCameraTick,
                builder: (context, _, __) {
                  return ValueListenableBuilder<LatLng?>(
                    valueListenable: widget.searchBusStopHighlightListenable,
                    builder: (context, highlight, _) {
                      final cam = widget.mapController.camera;
                      final zoom =
                          cam.zoom.isFinite ? cam.zoom : kRomagnaMapZoom;
                      if (zoom < _kStopsShowMinZoom) {
                        return const SizedBox.shrink();
                      }
                      final bounds = cam.visibleBounds;

                      if (zoom < _kStopsFullPinZoom) {
                        final dotD = _stopPreviewDotDiameter(zoom);
                        final borderW = (dotD * 0.2).clamp(1.0, 2.0);
                        return MarkerLayer(
                          markers: [
                            for (final pin in widget.busStops)
                              if (bounds.contains(pin.point))
                                Marker(
                                  point: pin.point,
                                  width: dotD + 8,
                                  height: dotD + 8,
                                  alignment: Alignment.center,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _onBusStopMarkerTap(pin),
                                    child: Builder(
                                      builder: (context) {
                                        final isMetromare = _isMetromarePin(
                                          pin,
                                        );
                                        final isSelected =
                                            _selectedBusStop != null &&
                                            pinsNearlySameLocation(
                                              pin.point,
                                              _selectedBusStop!.point,
                                            );
                                        final dotColor =
                                            isMetromare
                                                ? (isSelected
                                                    ? kFerrySelectedDarkYellow
                                                    : kMetromareRed)
                                                : kStopBusOrange;
                                        return Center(
                                          child: Container(
                                            width: dotD,
                                            height: dotD,
                                            decoration: BoxDecoration(
                                              color: dotColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: borderW,
                                              ),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0x33000000),
                                                  blurRadius: 3,
                                                  offset: Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                          ],
                        );
                      }

                      final iconSize = _stopIconSizeForZoom(zoom);
                      final markerPad = 5.0 + (zoom - _kStopsFullPinZoom) * 0.4;
                      final markerSize = iconSize + 2 * markerPad;
                      return MarkerLayer(
                        markers: [
                          for (final pin in widget.busStops)
                            if (bounds.contains(pin.point))
                              Marker(
                                point: pin.point,
                                width: markerSize,
                                height: markerSize + 2,
                                alignment: Alignment.bottomCenter,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _onBusStopMarkerTap(pin),
                                  child: Builder(
                                    builder: (context) {
                                      final isMetromare = _isMetromarePin(pin);
                                      final isSelected =
                                          _selectedBusStop != null &&
                                          pinsNearlySameLocation(
                                            pin.point,
                                            _selectedBusStop!.point,
                                          );
                                      final isHighlighted =
                                          highlight != null &&
                                          pinsNearlySameLocation(
                                            pin.point,
                                            highlight,
                                          );
                                      final baseColor =
                                          isMetromare
                                              ? kMetromareRed
                                              : kStopBusOrange;
                                      final highlightedColor =
                                          isMetromare
                                              ? kMetromareRedDark
                                              : kStopBusOrangeDark;
                                      final selectedColor =
                                          isMetromare
                                              ? kFerrySelectedDarkYellow
                                              : const Color(0xFF2B3A4A);
                                      return Material(
                                        elevation: isSelected ? 3 : 1,
                                        shadowColor:
                                            isSelected
                                                ? Colors.black38
                                                : Colors.black26,
                                        shape: const CircleBorder(),
                                        color:
                                            isSelected
                                                ? selectedColor
                                                : isHighlighted
                                                ? highlightedColor
                                                : baseColor,
                                        child: Padding(
                                          padding: const EdgeInsets.all(2.5),
                                          child:
                                              isMetromare
                                                  ? SizedBox(
                                                    width: iconSize,
                                                    height: iconSize,
                                                    child: Center(
                                                      child: Text(
                                                        'M',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style:
                                                            GoogleFonts.comicNeue(
                                                              fontSize:
                                                                  iconSize *
                                                                  0.88,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              height: 1.0,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                      ),
                                                    ),
                                                  )
                                                  : Icon(
                                                    Icons
                                                        .directions_bus_rounded,
                                                    size: iconSize,
                                                    color: Colors.white,
                                                  ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                        ],
                      );
                    },
                  );
                },
              ),
            _mapBottomLeftChrome(),
          ],
        ),
        if (_selectedBusStop != null)
          ValueListenableBuilder<int>(
            valueListenable: _mapCameraTick,
            builder: (context, _, __) => _busStopPopupOverlay(context),
          ),
        if (_selectedFerryStop != null)
          ValueListenableBuilder<int>(
            valueListenable: _mapCameraTick,
            builder: (context, _, __) => _ferryStopPopupOverlay(context),
          ),
      ],
    );
  }

  /// Solo pulsante «tipo mappa». Le attribuzioni legali dei tile sono in
  /// Altro → Crediti mappe (non sulla mappa, per richiesta UX).
  Widget _mapBottomLeftChrome() {
    final mq = MediaQuery.of(context);
    final fabRowBottom = widget.mapFabBottomPx;

    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16 + mq.padding.left, 0, 0, fabRowBottom),
        child: _MapLayerMenuFab(onPressed: () => _openMapLayerPicker(context)),
      ),
    );
  }

  Future<void> _openMapLayerPicker(BuildContext context) async {
    final chosen = await showGeneralDialog<RomagnaMapRasterKind>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return _MapLayerPickerContent(
          current: _rasterKind,
          onPick: (kind) => Navigator.of(ctx).pop(kind),
        );
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(ctx).pop(),
              child: const SizedBox.expand(),
            ),
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1, 0),
                end: Offset.zero,
              ).animate(curved),
              child: Align(alignment: Alignment.centerLeft, child: child),
            ),
          ],
        );
      },
    );
    if (!mounted || chosen == null || chosen == _rasterKind) return;
    setState(() => _rasterKind = chosen);
  }

  /// Card sopra il pinpoint: nome fermata + comune (provincia) da Photon.
  Widget _busStopPopupOverlay(BuildContext context) {
    final pin = _selectedBusStop!;
    final isMetromareCard = _isMetromarePin(pin);
    final cardBorderColor = isMetromareCard ? kMetromareRed : kStopBusOrange;
    Offset offset;
    try {
      offset = widget.mapController.camera.latLngToScreenOffset(pin.point);
    } catch (_) {
      return const SizedBox.shrink();
    }

    const cardW = 208.0;
    final hasCode = pin.stopId.isNotEmpty;
    final hasDisabili = pin.disabili == 'yes' || pin.disabili == 'no';
    final zoneCode = _extractZoneCode(pin.zona);
    final hasZona = zoneCode != null;
    final showExtraurbanE =
        pin.stopId.trim().isNotEmpty
            ? widget.scheduleIndex.stopHasExtraurbanLine(
              rawStopId: pin.stopId,
              lineeByComposite: widget.lineeByComposite,
            )
            : widget.transitiIndex.stopHasExtraurbanLineInTransit(pin.stopName);

    final stopCardIconTray = <Widget>[
      if (hasDisabili)
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFF1E40FF),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.accessible_rounded,
                size: 15,
                color: Colors.white,
              ),
            ),
            if (pin.disabili == 'no')
              Transform.rotate(
                angle: -0.65,
                child: Container(
                  width: 24,
                  height: 2.4,
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      if (showExtraurbanE) const _StopCardExtraurbanEBubble(),
      if (hasZona)
        Container(
          constraints: const BoxConstraints(minHeight: 22),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _zoneBubbleColor(zoneCode),
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            zoneCode,
            style: GoogleFonts.robotoCondensed(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ),
    ];

    // Altezza dinamica: evita overflow con testi su 2+ righe mantenendo card compatta.
    final stopNameUi = transitStopNameForDisplay(pin.stopName);
    final isLongName = stopNameUi.length > 24;
    final placeText = _busStopPlaceLine ?? 'Località non disponibile';
    final isLongPlace = !_busStopPlaceLoading && placeText.length > 30;
    final baseCardH =
        hasCode
            ? (isLongName || isLongPlace ? 124.0 : 112.0)
            : (isLongName || isLongPlace ? 110.0 : 98.0);
    final hasLongText = isLongName || isLongPlace;
    final iconSectionExtraHeight =
        (hasDisabili || hasZona || showExtraurbanE)
            ? (hasLongText ? 30.0 : 16.0)
            : 0.0;
    final minCardH = baseCardH + iconSectionExtraHeight;
    const tailW = 14.0;
    const tailH = 8.0;
    const markerRadius = 13.0;
    const markerLift = 0.0;
    final totalH = minCardH + tailH + markerRadius;

    final mq = MediaQuery.sizeOf(context);
    var left = offset.dx - cardW / 2;
    var top = offset.dy - markerLift - minCardH - tailH - markerRadius;
    left = left.clamp(8.0, mq.width - cardW - 8.0);
    top = top.clamp(8.0, mq.height - totalH - 8.0);

    return Positioned(
      left: left,
      top: top,
      width: cardW,
      child: TweenAnimationBuilder<double>(
        key: ValueKey<String>(
          pin.stopId.isNotEmpty ? pin.stopId : pin.stopName,
        ),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 230),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          final dy = (1 - t) * 12;
          return Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, dy), child: child),
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Material(
              elevation: 8,
              shadowColor: Colors.black38,
              borderRadius: BorderRadius.circular(18),
              color: Colors.white,
              child: Container(
                width: cardW,
                constraints: BoxConstraints(minHeight: minCardH),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cardBorderColor, width: 2.0),
                ),
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stopNameUi,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kRomagnaDarkGray,
                        height: 1.2,
                      ),
                    ),
                    if (hasCode) ...[
                      const SizedBox(height: 6),
                      Text(
                        pin.stopId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          color: kRomagnaPrimary,
                        ),
                      ),
                    ],
                    SizedBox(height: hasCode ? 7 : 5),
                    if (_busStopPlaceLoading)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kRomagnaPrimary,
                        ),
                      )
                    else
                      Text(
                        _busStopPlaceLine ?? 'Località non disponibile',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                          color: kRomagnaDarkGray.withValues(alpha: 0.72),
                        ),
                      ),
                    if (stopCardIconTray.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          for (var i = 0; i < stopCardIconTray.length; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            stopCardIconTray[i],
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -tailH,
              child: CustomPaint(
                size: Size(tailW, tailH),
                painter: _BubbleTrianglePainter(color: cardBorderColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ferryStopPopupOverlay(BuildContext context) {
    final ferry = _selectedFerryStop!;
    Offset offset;
    try {
      offset = widget.mapController.camera.latLngToScreenOffset(ferry.point);
    } catch (_) {
      return const SizedBox.shrink();
    }

    const cardW = 208.0;
    const minCardH = 98.0;
    const tailW = 14.0;
    const tailH = 8.0;
    const markerRadius = 13.0;
    const markerLift = 0.0;
    const totalH = minCardH + tailH + markerRadius;

    final mq = MediaQuery.sizeOf(context);
    var left = offset.dx - cardW / 2;
    var top = offset.dy - markerLift - minCardH - tailH - markerRadius;
    left = left.clamp(8.0, mq.width - cardW - 8.0);
    top = top.clamp(8.0, mq.height - totalH - 8.0);

    return Positioned(
      left: left,
      top: top,
      width: cardW,
      child: TweenAnimationBuilder<double>(
        key: ValueKey<String>('ferry_${ferry.id}'),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 230),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          final dy = (1 - t) * 12;
          return Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, dy), child: child),
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Material(
              elevation: 8,
              shadowColor: Colors.black38,
              borderRadius: BorderRadius.circular(18),
              color: Colors.white,
              child: Container(
                width: cardW,
                constraints: const BoxConstraints(minHeight: minCardH),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: kFerryElectricBlue, width: 2.0),
                ),
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transitStopNameForDisplay(ferry.stopName),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kRomagnaDarkGray,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${ferry.comune} (${ferry.provincia})',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                        color: kRomagnaDarkGray.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: kFerryElectricBlue,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.directions_boat_filled_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -tailH,
              left: cardW / 2 - tailW / 2,
              child: CustomPaint(
                size: const Size(tailW, tailH),
                painter: _BubbleTrianglePainter(color: kFerryElectricBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _extractZoneCode(String zona) {
    final match = RegExp(r'\((\d{3})\)').firstMatch(zona);
    return match?.group(1);
  }

  Color _zoneBubbleColor(String? zoneCode) {
    if (zoneCode == null || zoneCode.isEmpty) return const Color(0xFF757575);
    if (zoneCode.startsWith('7')) return const Color(0xFF008ED0);
    if (zoneCode.startsWith('8')) return const Color(0xFF009B4C);
    if (zoneCode.startsWith('9')) return const Color(0xFFEC1D25);
    return const Color(0xFF757575);
  }
}

/// Bubble «E» extraurbano nella card fermata (stesso ingombro dell’icona accessibilità).
class _StopCardExtraurbanEBubble extends StatelessWidget {
  const _StopCardExtraurbanEBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Text(
        'E',
        textAlign: TextAlign.center,
        style: GoogleFonts.archivoBlack(
          fontSize: 12,
          height: 1.0,
          color: Colors.black,
        ),
      ),
    );
  }
}

class _BubbleTrianglePainter extends CustomPainter {
  _BubbleTrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final path =
        ui.Path()
          ..moveTo(
            size.width / 2,
            size.height,
          ) // Punta in basso (verso il marker)
          ..lineTo(0, 0) // Angolo sinistro alto
          ..lineTo(size.width, 0) // Angolo destro alto
          ..close();

    // Disegna l'ombra del triangolo
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.15), 3, false);
    // Disegna il triangolo arancione
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -----------------------------------------------------------------------------
// FAB «tipo mappa» (stesso ingombro del pulsante posizione a destra).
// -----------------------------------------------------------------------------
class _MapLayerMenuFab extends StatelessWidget {
  const _MapLayerMenuFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Tipo di mappa',
      child: _MapCircularControl(
        onTap: onPressed,
        padding: const EdgeInsets.all(12),
        child: Icon(Icons.layers_rounded, color: kRomagnaPrimary, size: 22),
      ),
    );
  }
}

/// Pannello lista layer (scroll orizzontale) per [showGeneralDialog].
class _MapLayerPickerContent extends StatefulWidget {
  const _MapLayerPickerContent({required this.current, required this.onPick});

  final RomagnaMapRasterKind current;
  final ValueChanged<RomagnaMapRasterKind> onPick;

  @override
  State<_MapLayerPickerContent> createState() => _MapLayerPickerContentState();
}

class _MapLayerPickerContentState extends State<_MapLayerPickerContent> {
  final ScrollController _scrollController = ScrollController();
  int _scrollLayoutWaits = 0;

  @override
  void initState() {
    super.initState();
    _scrollLayoutWaits = 0;
    // Doppio post-frame: dopo l’animazione d’ingresso del dialog lo scroll extent è stabile.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryScrollToSelected();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _tryScrollToSelected(),
      );
    });
  }

  @override
  void didUpdateWidget(covariant _MapLayerPickerContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) {
      _scrollLayoutWaits = 0;
      _scheduleScrollToSelected();
    }
  }

  void _scheduleScrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryScrollToSelected());
  }

  void _tryScrollToSelected() {
    if (!mounted) return;
    if (!_scrollController.hasClients) {
      if (_scrollLayoutWaits++ < 12) _scheduleScrollToSelected();
      return;
    }
    final idx = _mapLayerPickerIndex(widget.current);
    final target = idx * _kMapLayerPickerTileStride;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0 && idx > 0) {
      if (_scrollLayoutWaits++ < 12) _scheduleScrollToSelected();
      return;
    }
    _scrollController.jumpTo(target.clamp(0.0, max));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxW = math.min(mq.size.width * 0.96, 560.0);
    final current = widget.current;
    final onPick = widget.onPick;

    return Material(
      elevation: 14,
      shadowColor: Colors.black38,
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
      color: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tipo di mappa',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kRomagnaDarkGray,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Scegli un layer per la mappa',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: kRomagnaDarkGray.withValues(alpha: 0.48),
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _MapLayerOptionTile(
                      title: 'Standard',
                      subtitle: 'Mappa dettagliata',
                      icon: Icons.public_rounded,
                      selected: current == RomagnaMapRasterKind.humanitarianHot,
                      onTap: () => onPick(RomagnaMapRasterKind.humanitarianHot),
                    ),
                    const SizedBox(width: 10),
                    _MapLayerOptionTile(
                      title: 'Satellite',
                      subtitle: 'Immagini satellitari',
                      icon: Icons.satellite_alt_outlined,
                      selected: current == RomagnaMapRasterKind.satelliteEsri,
                      onTap: () => onPick(RomagnaMapRasterKind.satelliteEsri),
                    ),
                    const SizedBox(width: 10),
                    _MapLayerOptionTile(
                      title: 'CyclOSM',
                      subtitle: 'Percorsi ciclabili',
                      icon: Icons.directions_bike_outlined,
                      selected: current == RomagnaMapRasterKind.cyclOsm,
                      onTap: () => onPick(RomagnaMapRasterKind.cyclOsm),
                    ),
                    const SizedBox(width: 10),
                    _MapLayerOptionTile(
                      title: 'White',
                      subtitle: 'Strade · giorno',
                      icon: Icons.wb_sunny_outlined,
                      selected: current == RomagnaMapRasterKind.whiteCarto,
                      onTap: () => onPick(RomagnaMapRasterKind.whiteCarto),
                    ),
                    const SizedBox(width: 10),
                    _MapLayerOptionTile(
                      title: 'Black',
                      subtitle: 'Strade · notte',
                      icon: Icons.dark_mode_outlined,
                      selected: current == RomagnaMapRasterKind.darkCarto,
                      onTap: () => onPick(RomagnaMapRasterKind.darkCarto),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapLayerOptionTile extends StatelessWidget {
  const _MapLayerOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 152,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color:
                selected
                    ? kRomagnaPrimary.withValues(alpha: 0.12)
                    : kRomagnaDarkGray.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  selected
                      ? kRomagnaPrimary.withValues(alpha: 0.55)
                      : kRomagnaDarkGray.withValues(alpha: 0.12),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 26,
                color: selected ? kRomagnaPrimary : kRomagnaDarkGray,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kRomagnaDarkGray,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  height: 1.3,
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

// -----------------------------------------------------------------------------
// Pulsante zoom circolare (stile coerente col FAB posizione).
// -----------------------------------------------------------------------------
class _MapZoomButton extends StatelessWidget {
  const _MapZoomButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _MapCircularControl(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Icon(icon, color: kRomagnaPrimary, size: 22),
    );
  }
}

class _MapCircularControl extends StatelessWidget {
  const _MapCircularControl({
    required this.onTap,
    required this.child,
    required this.padding,
  });

  final VoidCallback onTap;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      color: Colors.white,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: kRomagnaPrimary.withValues(alpha: 0.52),
              width: 1.2,
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Pannello risultati ricerca: glassmorphism (blur + bordo chiaro + vetro).
// -----------------------------------------------------------------------------
class _GlassAutocompleteResults extends StatelessWidget {
  const _GlassAutocompleteResults({
    required this.maxHeight,
    required this.child,
    this.addTopPadding = true,
  });

  final double maxHeight;
  final Widget child;
  final bool addTopPadding;

  @override
  Widget build(BuildContext context) {
    final glass = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.92),
              width: 1.1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.5),
                Colors.white.withValues(alpha: 0.26),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: child,
            ),
          ),
        ),
      ),
    );
    if (!addTopPadding) return glass;
    return Padding(padding: const EdgeInsets.only(top: 6), child: glass);
  }
}

// -----------------------------------------------------------------------------
// Barra di ricerca: pill con clip (niente rettangoli bianchi), autocomplete OSM Romagna, Invio / tap centra la mappa.
// -----------------------------------------------------------------------------
class _MapSearchBar extends StatefulWidget {
  const _MapSearchBar({
    required this.mapController,
    required this.controller,
    required this.searchFocusNode,
    required this.dismissRequests,
    required this.minSearchChars,
    required this.transitStops,
    required this.ferryStops,
    required this.maxTransitStops,
    required this.sortStopsByDistance,
    required this.searchPinListenable,
    required this.searchBusStopHighlightNotifier,
    required this.priorityOriginResolver,
    required this.onClearSearchAndPins,
    required this.onSearchResultChosen,
  });

  final MapController mapController;
  final TextEditingController controller;
  final FocusNode searchFocusNode;
  final ValueListenable<int> dismissRequests;
  final int minSearchChars;
  final List<TransitStopPin> transitStops;
  final List<FerryStopPin> ferryStops;
  final int maxTransitStops;
  final bool sortStopsByDistance;
  final ValueListenable<LatLng?> searchPinListenable;
  final ValueNotifier<LatLng?> searchBusStopHighlightNotifier;
  final LatLng Function() priorityOriginResolver;
  final VoidCallback onClearSearchAndPins;
  final ValueChanged<RomagnaAddressHit> onSearchResultChosen;

  @override
  State<_MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<_MapSearchBar> {
  late VoidCallback _dismissListener;
  int _lastDismissGen = 0;

  Timer? _debounce;
  List<RomagnaAddressHit> _hits = [];
  int _searchSeq = 0;

  void _onMapPinsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scheduleSearch);
    widget.searchPinListenable.addListener(_onMapPinsChanged);
    widget.searchBusStopHighlightNotifier.addListener(_onMapPinsChanged);
    widget.searchFocusNode.addListener(_onSearchFocusChanged);
    _lastDismissGen = widget.dismissRequests.value;
    _dismissListener = () {
      final g = widget.dismissRequests.value;
      if (g == _lastDismissGen) return;
      _lastDismissGen = g;
      if (!mounted) return;
      widget.searchFocusNode.unfocus();
      setState(() => _hits = []);
    };
    widget.dismissRequests.addListener(_dismissListener);
  }

  void _onSearchFocusChanged() {
    if (widget.searchFocusNode.hasFocus) {
      setState(() {});
      return;
    }
    _debounce?.cancel();
    _searchSeq++;
    setState(() => _hits = []);
  }

  @override
  void dispose() {
    widget.dismissRequests.removeListener(_dismissListener);
    widget.searchFocusNode.removeListener(_onSearchFocusChanged);
    widget.controller.removeListener(_scheduleSearch);
    widget.searchPinListenable.removeListener(_onMapPinsChanged);
    widget.searchBusStopHighlightNotifier.removeListener(_onMapPinsChanged);
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    final text = widget.controller.text.trim();
    if (text.length < 2) {
      widget.searchBusStopHighlightNotifier.value = null;
      setState(() => _hits = []);
      return;
    }
    if (text.length < widget.minSearchChars) {
      setState(
        () =>
            _hits =
                busStopHitsForMapSearch(
                  text,
                  widget.transitStops,
                  ferryStops: widget.ferryStops,
                  priorityOrigin: widget.priorityOriginResolver(),
                  sortStopsByDistance: true,
                ).take(widget.maxTransitStops).toList(),
      );
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: kRomagnaSearchDebounceMs),
      () => _runSearch(text),
    );
    setState(() {});
  }

  Future<void> _runSearch(String queryAtSchedule) async {
    final seq = ++_searchSeq;
    final results = await searchRomagnaMapWithTransit(
      queryAtSchedule,
      transitStops: widget.transitStops,
      ferryStops: widget.ferryStops,
      priorityOrigin: widget.priorityOriginResolver(),
      minCharsRemote: widget.minSearchChars,
      maxTransitStops: widget.maxTransitStops,
      sortStopsByDistance: true,
    );
    if (!mounted || seq != _searchSeq) return;
    if (widget.controller.text.trim() != queryAtSchedule) return;
    setState(() => _hits = results);
  }

  /// Imposta il testo della barra senza rilanciare l'autocomplete (evita che il
  /// dropdown riappaia dopo la selezione di un risultato).
  void _setSearchFieldTextSilently(String line) {
    widget.controller.removeListener(_scheduleSearch);
    widget.controller.text = line;
    widget.controller.selection = TextSelection.collapsed(offset: line.length);
    widget.controller.addListener(_scheduleSearch);
  }

  void _applyHit(RomagnaAddressHit hit) {
    if (!isValidMapLatLng(hit.point)) return;
    _debounce?.cancel();
    _searchSeq++;
    widget.onSearchResultChosen(hit);
    final line = romagnaHitDisplayLine(hit);
    _setSearchFieldTextSilently(line);
    setState(() => _hits = []);
    widget.searchFocusNode.unfocus();
  }

  /// Lista mista fermate (priorità) + indirizzi, con etichette sezione se entrambe presenti.
  List<Widget> _mapSearchHitListChildren() {
    return _hits
        .map(
          (hit) => ListTile(
            dense: true,
            title: romagnaSearchHitListTitle(hit),
            subtitle: romagnaSearchHitListSubtitle(hit),
            leading: romagnaSearchHitLeadingWidget(hit),
            onTap: hit.isSearchMessage ? null : () => _applyHit(hit),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _onSearchSubmitted() async {
    final q = widget.controller.text.trim();
    if (q.length < 2) return;
    if (q.length < widget.minSearchChars) {
      final stops =
          busStopHitsForMapSearch(
            q,
            widget.transitStops,
            ferryStops: widget.ferryStops,
            priorityOrigin: widget.priorityOriginResolver(),
            sortStopsByDistance: true,
          ).take(widget.maxTransitStops).toList();
      if (stops.isEmpty) return;
      _applyHit(stops.first);
      return;
    }
    if (_hits.isNotEmpty) {
      if (!_hits.first.isSearchMessage) {
        _applyHit(_hits.first);
        return;
      }
    }
    final results = await searchRomagnaMapWithTransit(
      q,
      transitStops: widget.transitStops,
      ferryStops: widget.ferryStops,
      priorityOrigin: widget.priorityOriginResolver(),
      minCharsRemote: widget.minSearchChars,
      maxTransitStops: widget.maxTransitStops,
      sortStopsByDistance: true,
    );
    if (!mounted) return;
    if (results.isEmpty) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Nessun indirizzo trovato in Romagna per «$q»',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.3,
              color: Colors.white,
            ),
          ),
          backgroundColor: kRomagnaDarkGray.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      widget.searchFocusNode.unfocus();
      return;
    }
    setState(() => _hits = results);
    _applyHit(results.first);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          elevation: 6,
          shadowColor: Colors.black26,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.searchFocusNode,
                    style: GoogleFonts.inter(
                      color: kRomagnaDarkGray,
                      fontSize: 15,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _onSearchSubmitted(),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      fillColor: Colors.transparent,
                      hintText: 'Cerca un indirizzo',
                      hintStyle: GoogleFonts.inter(
                        color: kRomagnaDarkGray.withValues(alpha: 0.45),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                if (widget.controller.text.isNotEmpty ||
                    widget.searchPinListenable.value != null ||
                    widget.searchBusStopHighlightNotifier.value != null)
                  Tooltip(
                    message: 'Cancella ricerca e pin sulla mappa',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.onClearSearchAndPins,
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2, right: 2),
                          child: Icon(
                            Icons.close_rounded,
                            color: kRomagnaDarkGray.withValues(alpha: 0.45),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _onSearchSubmitted,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8, left: 4),
                      child: Icon(
                        Icons.search,
                        color: kRomagnaPrimary,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if ((_hits.isNotEmpty || widget.controller.text.trim().length >= 2) &&
            widget.searchFocusNode.hasFocus)
          _GlassAutocompleteResults(
            maxHeight: 300,
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: _mapSearchHitListChildren(),
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Pill «Biglietto»: apre la schermata biglietti (non è più una voce del menù basso).
// -----------------------------------------------------------------------------
class _BigliettoPill extends StatelessWidget {
  const _BigliettoPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(999),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: kRomagnaPrimary.withValues(alpha: 0.52),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.confirmation_number_outlined,
                  size: 18,
                  color: kRomagnaPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Biglietto',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kRomagnaDarkGray,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IndirizziRapidiPill extends StatelessWidget {
  const _IndirizziRapidiPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(999),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: kRomagnaPrimary.withValues(alpha: 0.52),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bookmarks_outlined,
                  size: 18,
                  color: kRomagnaPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Indirizzi rapidi',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kRomagnaDarkGray,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickSheetRow extends StatelessWidget {
  const _QuickSheetRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onRemove,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: kRomagnaDarkGray.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: kRomagnaPrimary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: kRomagnaDarkGray,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: kRomagnaDarkGray.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
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
            ),
            if (onRemove != null)
              IconButton(
                tooltip: 'Rimuovi',
                onPressed: onRemove,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: kRomagnaDarkGray.withValues(alpha: 0.45),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddressNearbyStopTile extends StatelessWidget {
  const _QuickAddressNearbyStopTile({
    required this.pin,
    required this.distanceLabel,
    required this.rank,
    required this.onOpenStop,
  });

  final TransitStopPin pin;
  final String distanceLabel;
  final int rank;
  final VoidCallback onOpenStop;

  @override
  Widget build(BuildContext context) {
    final nameUi = transitStopNameForDisplay(pin.stopName);
    final meta = <String>[
      if (pin.stopId.isNotEmpty) pin.stopId,
      if (pin.comune.isNotEmpty) pin.comune,
      distanceLabel,
    ].join(' · ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenStop,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  '$rank.',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: kRomagnaPrimary,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nameUi,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.25,
                        color: kRomagnaDarkGray,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.3,
                        color: kRomagnaDarkGray.withValues(alpha: 0.52),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: kRomagnaDarkGray.withValues(alpha: 0.38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Contenuto foglio mappa: tab filtro + area risultati (maniglia sul genitore).
// -----------------------------------------------------------------------------
String _romagnaQuickAddressSubtitle(RomagnaAddressHit hit) {
  final t = hit.label.trim();
  if (t.isNotEmpty) return t;
  return romagnaHitDisplayLine(hit);
}

class _CurrentLocationNearbyStopsPanel extends StatelessWidget {
  const _CurrentLocationNearbyStopsPanel({
    required this.origin,
    required this.nearbyStops,
    required this.nearbyPending,
    required this.onNearbyStopTap,
    this.title = 'Posizione attuale',
    this.subtitle = 'Fermate più vicine a te',
    this.leadingIcon = Icons.my_location_rounded,
  });

  final LatLng origin;
  final List<TransitStopPin> nearbyStops;
  final bool nearbyPending;
  final ValueChanged<TransitStopPin> onNearbyStopTap;
  final String title;
  final String subtitle;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    final addrStyle = GoogleFonts.inter(
      fontSize: 12.5,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: kRomagnaDarkGray.withValues(alpha: 0.58),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: kRomagnaPrimary.withValues(alpha: 0.28),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kRomagnaPrimary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(leadingIcon, size: 22, color: kRomagnaPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kRomagnaDarkGray,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: addrStyle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: kRomagnaPrimary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: kRomagnaPrimary.withValues(alpha: 0.18),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fermate nelle vicinanze',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: kRomagnaDarkGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (nearbyPending)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: kRomagnaPrimary.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Calcolo fermate vicine…',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                  color: kRomagnaDarkGray.withValues(
                                    alpha: 0.52,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (nearbyStops.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Nessuna fermata rilevata nelle vicinanze.',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            height: 1.35,
                            color: kRomagnaDarkGray.withValues(alpha: 0.52),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (var i = 0; i < nearbyStops.length; i++)
                            _QuickAddressNearbyStopTile(
                              pin: nearbyStops[i],
                              distanceLabel: formatWalkingDistanceMeters(
                                Distance().as(
                                  LengthUnit.Meter,
                                  origin,
                                  nearbyStops[i].point,
                                ),
                              ),
                              rank: i + 1,
                              onOpenStop: () => onNearbyStopTap(nearbyStops[i]),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddressSheetPanel extends StatelessWidget {
  const _QuickAddressSheetPanel({
    required this.detail,
    required this.nearbyStops,
    required this.nearbyPending,
    required this.onEdit,
    required this.onRemove,
    required this.onNearbyStopTap,
  });

  final QuickAddressMarkerTapDetails detail;
  final List<TransitStopPin> nearbyStops;
  final bool nearbyPending;
  final Future<void> Function() onEdit;
  final VoidCallback onRemove;
  final ValueChanged<TransitStopPin> onNearbyStopTap;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final addrStyle = GoogleFonts.inter(
      fontSize: 12.5,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: kRomagnaDarkGray.withValues(alpha: 0.58),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: kRomagnaPrimary.withValues(alpha: 0.28),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kRomagnaPrimary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(d.icon, size: 22, color: kRomagnaPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kRomagnaDarkGray,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _romagnaQuickAddressSubtitle(d.hit),
                        style: addrStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () async {
                      await onEdit();
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Modifica indirizzo',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRemove,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Rimuovi indirizzo',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: kRomagnaPrimary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: kRomagnaPrimary.withValues(alpha: 0.18),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fermate nelle vicinanze',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: kRomagnaDarkGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (nearbyPending)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: kRomagnaPrimary.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Calcolo fermate vicine…',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                  color: kRomagnaDarkGray.withValues(
                                    alpha: 0.52,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (nearbyStops.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Nessuna fermata rilevata nelle vicinanze.',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            height: 1.35,
                            color: kRomagnaDarkGray.withValues(alpha: 0.52),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (var i = 0; i < nearbyStops.length; i++)
                            _QuickAddressNearbyStopTile(
                              pin: nearbyStops[i],
                              distanceLabel: formatWalkingDistanceMeters(
                                Distance().as(
                                  LengthUnit.Meter,
                                  d.hit.point,
                                  nearbyStops[i].point,
                                ),
                              ),
                              rank: i + 1,
                              onOpenStop: () => onNearbyStopTap(nearbyStops[i]),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RomagnaBottomSheet extends StatelessWidget {
  const _RomagnaBottomSheet({
    required this.scrollController,
    required this.scrollLocked,
    required this.selectedFilterIndex,
    required this.onFilterSelected,
    required this.busStopSheetLines,
    required this.scheduleIndex,
    required this.lineeByComposite,
    required this.onQuickAddressEdit,
    required this.onQuickAddressRemove,
    required this.onQuickAddressNearbyStopSelected,
  });

  final ScrollController scrollController;
  final bool scrollLocked;
  final int selectedFilterIndex;
  final ValueChanged<int> onFilterSelected;
  final ValueListenable<BusStopSheetLinesPayload?> busStopSheetLines;
  final StopTransitScheduleIndex scheduleIndex;
  final Map<String, RomagnaLineaRow> lineeByComposite;

  final Future<void> Function(QuickAddressMarkerTapDetails d)
  onQuickAddressEdit;
  final void Function(QuickAddressMarkerTapDetails d) onQuickAddressRemove;
  final void Function(TransitStopPin pin) onQuickAddressNearbyStopSelected;

  static const _filters = [
    (Icons.directions_transit_filled, 'Mezzi pubblici'),
    (Icons.electric_moped_outlined, 'Mobilità elettrica'),
  ];

  static const Color _kExtraurbanBubbleBg = Color(0xFF1E3A5F);

  @override
  Widget build(BuildContext context) {
    // Maniglia e bordo arrotondato: il genitore ([Material] sullo stack mappa).
    return ListView(
      controller: scrollController,
      physics:
          scrollLocked
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 6),
        SizedBox(
          height: kSheetSnapFilterRowPx,
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final sel = index == selectedFilterIndex;
              final item = _filters[index];
              return _SheetFilterChip(
                icon: item.$1,
                label: item.$2,
                selected: sel,
                onTap: () => onFilterSelected(index),
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        ValueListenableBuilder<BusStopSheetLinesPayload?>(
          valueListenable: busStopSheetLines,
          builder: (context, payload, _) {
            if (selectedFilterIndex == 1) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      'Nessun risultato',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kRomagnaDarkGray.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Contenuti in arrivo',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.35,
                        color: kRomagnaDarkGray.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            }
            if (payload == null) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      'Nessun risultato',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kRomagnaDarkGray.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Seleziona una fermata sulla mappa o cerca un indirizzo',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.35,
                        color: kRomagnaDarkGray.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            }
            final currentLocationOrigin = payload.nearbyOriginPoint;
            if (currentLocationOrigin != null) {
              final anchoredToUser = payload.nearbyAnchoredToUserLocation;
              final anchorLabel = payload.nearbyAnchorLabel?.trim();
              return _CurrentLocationNearbyStopsPanel(
                origin: currentLocationOrigin,
                nearbyStops: payload.nearbyStops,
                nearbyPending: payload.nearbyPending,
                onNearbyStopTap: onQuickAddressNearbyStopSelected,
                title:
                    anchoredToUser
                        ? 'Posizione attuale'
                        : 'Indirizzo selezionato',
                subtitle:
                    anchoredToUser
                        ? 'Fermate più vicine a te'
                        : (anchorLabel != null && anchorLabel.isNotEmpty
                            ? anchorLabel
                            : 'Fermate più vicine a questo punto'),
                leadingIcon:
                    anchoredToUser
                        ? Icons.my_location_rounded
                        : Icons.place_outlined,
              );
            }
            final quickDetail = payload.quickAddressDetail;
            if (quickDetail != null) {
              return _QuickAddressSheetPanel(
                detail: quickDetail,
                nearbyStops: payload.quickAddressNearbyStops,
                nearbyPending: payload.quickAddressNearbyPending,
                onEdit: () => onQuickAddressEdit(quickDetail),
                onRemove: () => onQuickAddressRemove(quickDetail),
                onNearbyStopTap: onQuickAddressNearbyStopSelected,
              );
            }
            if (payload.isFerry) {
              final stopNameUi = transitStopNameForDisplay(
                payload.stopNameRaw ?? 'Traghetto Ravenna',
              );
              final placeLine =
                  payload.ferryComuneProvincia ??
                  'Porto Corsini – Marina di Ravenna';
              final infoStyle = GoogleFonts.inter(
                fontSize: 13,
                height: 1.4,
                color: kRomagnaDarkGray.withValues(alpha: 0.82),
              );
              final bulletStyle = GoogleFonts.inter(
                fontSize: 13,
                height: 1.42,
                color: kRomagnaDarkGray.withValues(alpha: 0.82),
              );
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: kFerryElectricBlue.withValues(alpha: 0.36),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: kFerryElectricBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.directions_boat_filled_rounded,
                              size: 17,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              stopNameUi,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: kRomagnaDarkGray,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        placeLine,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: kRomagnaDarkGray.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Traghetto Porto Corsini – Marina di Ravenna',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kRomagnaDarkGray,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Collegamento attivo tutto l’anno sul Canale Candiano. Servizio per pedoni, ciclisti, moto, auto e autocarri.',
                        style: infoStyle,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: kFerryElectricBlue,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Servizio giornaliero: 5:00 – 00:30 (orario invernale in vigore dal 14/09/2025)',
                              style: bulletStyle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.priority_high_rounded,
                            size: 16,
                            color: kFerryElectricBlue,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Fasce garantite in caso di sciopero: 5:30–8:30 e 12:00–15:00',
                              style: bulletStyle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.directions_bus_filled_rounded,
                            size: 16,
                            color: kFerryElectricBlue,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'In caso di interruzione per maltempo è previsto trasbordo pedonale via autobus senza costi aggiuntivi',
                              style: bulletStyle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Fonte: Start Romagna (Servizio Traghetto)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: kRomagnaDarkGray.withValues(alpha: 0.52),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            final lines = payload.bubbles;
            final urbanSuburban = <StopTransitLineBubble>[];
            final extraurbanLines = <StopTransitLineBubble>[];
            for (final b in lines) {
              if (b.isExtraurban) {
                extraurbanLines.add(b);
              } else {
                urbanSuburban.add(b);
              }
            }
            if (lines.isEmpty) {
              final catalogBad = payload.catalogLoadFailed;
              final schedBad = payload.scheduleLoadFailed;
              final sid = payload.stopId?.trim() ?? '';
              String title = 'Nessuna linea in elenco';
              String subtitle =
                  'Non risultano corse in partenza da questa fermata';
              if (sid.isEmpty) {
                title = 'Codice fermata non disponibile';
                subtitle =
                    'Questo punto non espone uno stop_id: non è possibile mostrare le linee dall’ultimo grafico caricato.';
              } else if (schedBad) {
                title = 'Orari fermata non disponibili';
                subtitle =
                    'Impossibile leggere gli orari di transito. Rigenerare assets/data/transit_times_by_stop.json.';
              } else if (catalogBad && sid.isNotEmpty && !schedBad) {
                title = 'Metadati linea limitati';
                subtitle =
                    'Grafico corse presente, ma alcune diciture potrebbero mancare.';
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: kRomagnaDarkGray.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.35,
                        color: kRomagnaDarkGray.withValues(alpha: 0.38),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            }
            Widget transitBubbleWrap(List<StopTransitLineBubble> items) {
              // Larghezza piena del foglio: così il Wrap riempie ogni riga in orizzontale
              // e va a capo solo quando le bubble non ci stanno più sulla stessa riga.
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    direction: Axis.horizontal,
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final b in items)
                        _TransitLineBubbleChip(
                          bubble: b,
                          extraurbanBg: _kExtraurbanBubbleBg,
                          onTap:
                              (payload.stopId == null ||
                                      payload.stopId!.trim().isEmpty ||
                                      payload.scheduleLoadFailed)
                                  ? null
                                  : () {
                                    final sid = payload.stopId!.trim();
                                    if (b.scheduleRouteKeys.isEmpty) {
                                      ScaffoldMessenger.maybeOf(
                                        context,
                                      )?.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Nessuna chiave orari per questa linea '
                                            'alla fermata (dati interni incompleti).',
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      return;
                                    }
                                    final raw = payload.stopNameRaw ?? '';
                                    final stopUi =
                                        raw.isEmpty
                                            ? sid
                                            : transitStopNameForDisplay(raw);
                                    RomagnaLineaRow? lineInfoRow;
                                    for (final composite
                                        in b.scheduleRouteKeys) {
                                      final row = lineeByComposite[composite];
                                      if (row != null) {
                                        lineInfoRow = row;
                                        break;
                                      }
                                    }
                                    final entriesToday = scheduleIndex
                                        .entriesForKeys(
                                          sid,
                                          b.scheduleRouteKeys,
                                          onLocalDay: DateTime.now(),
                                        );
                                    final entriesAll = scheduleIndex
                                        .entriesForKeys(
                                          sid,
                                          b.scheduleRouteKeys,
                                          applyServiceCalendarFilter: false,
                                        );
                                    showTransitLineDeparturesSheet(
                                      context,
                                      stopNameUi: stopUi,
                                      stopIdUi: sid,
                                      bubble: b,
                                      lineInfoRow: lineInfoRow,
                                      entriesToday: entriesToday,
                                      entriesAllProfiles: entriesAll,
                                      calendar:
                                          scheduleIndex.serviceCalendarOrNull,
                                    );
                                  },
                        ),
                    ],
                  ),
                ),
              );
            }

            const sectionTitlePadding = EdgeInsets.fromLTRB(20, 0, 20, 12);
            final sectionTitleStyle = GoogleFonts.inter(
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: kRomagnaDarkGray.withValues(alpha: 0.5),
              letterSpacing: 0.2,
            );

            return SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (urbanSuburban.isNotEmpty) ...[
                    Padding(
                      padding: sectionTitlePadding,
                      child: Text(
                        'Linee urbane e suburbane',
                        style: sectionTitleStyle,
                      ),
                    ),
                    transitBubbleWrap(urbanSuburban),
                  ],
                  if (urbanSuburban.isNotEmpty && extraurbanLines.isNotEmpty)
                    const SizedBox(height: 22),
                  if (extraurbanLines.isNotEmpty) ...[
                    Padding(
                      padding: sectionTitlePadding,
                      child: Text(
                        'Linee extraurbane',
                        style: sectionTitleStyle,
                      ),
                    ),
                    transitBubbleWrap(extraurbanLines),
                  ],
                  if ((payload.stopId ?? '').trim().isNotEmpty &&
                      lines.isNotEmpty &&
                      !payload.scheduleLoadFailed) ...[
                    const SizedBox(height: 26),
                    Padding(
                      padding: sectionTitlePadding,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            final sid = payload.stopId!.trim();
                            final raw = payload.stopNameRaw ?? '';
                            final stopUi =
                                raw.isEmpty
                                    ? sid
                                    : transitStopNameForDisplay(raw);
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder:
                                    (ctx) => StopAllDeparturesPage(
                                      rawStopId: sid,
                                      stopNameUi: stopUi,
                                      basinLower: payload.basinLower,
                                      lineeByComposite: lineeByComposite,
                                      schedule: scheduleIndex,
                                    ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Prossime partenze',
                                    style: sectionTitleStyle,
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 22,
                                  color: kRomagnaPrimary.withValues(
                                    alpha: 0.78,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
                      child: Builder(
                        builder: (ctx) {
                          final basinRt =
                              payload.basinLower?.trim().toLowerCase() ?? '';
                          final canInfobusRt =
                              (basinRt == 'fc' ||
                                  basinRt == 'ra' ||
                                  basinRt == 'rn');

                          if (canInfobusRt) {
                            final rawName = payload.stopNameRaw ?? '';
                            final stopUi =
                                rawName.isEmpty
                                    ? payload.stopId!.trim()
                                    : transitStopNameForDisplay(rawName);
                            return InfobusUpcomingDeparturesBlock(
                              rawStopId: payload.stopId!.trim(),
                              basinLower: basinRt,
                              bubbles: lines,
                              schedule: scheduleIndex,
                              onTripTimeChipTap:
                                  (c, u, card, bubble) =>
                                      openTripTimetableForUpcomingDeparture(
                                        c,
                                        schedule: scheduleIndex,
                                        lineeByComposite: lineeByComposite,
                                        rawStopId: payload.stopId!.trim(),
                                        stopNameUi: stopUi,
                                        u: u,
                                        matchedSiteCard: card,
                                        bubble: bubble,
                                      ),
                              onPastTripTimeChipTap:
                                  (c, past, bubble) =>
                                      openTripTimetableForRecentPastDeparture(
                                        c,
                                        schedule: scheduleIndex,
                                        lineeByComposite: lineeByComposite,
                                        rawStopId: payload.stopId!.trim(),
                                        stopNameUi: stopUi,
                                        past: past,
                                        bubble: bubble,
                                      ),
                            );
                          }

                          final upcoming = computeUpcomingDeparturesUi(
                            rawStopId: payload.stopId!.trim(),
                            bubbles: lines,
                            schedule: scheduleIndex,
                            now: DateTime.now(),
                          );

                          final sid = payload.stopId!.trim();
                          final rawNameEmpty = payload.stopNameRaw ?? '';
                          final stopUiEmpty =
                              rawNameEmpty.isEmpty
                                  ? sid
                                  : transitStopNameForDisplay(rawNameEmpty);

                          if (upcoming.isEmpty) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    'Non ci sono partenze imminenti con i dati attuali.',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      height: 1.45,
                                      color: kRomagnaDarkGray.withValues(
                                        alpha: 0.42,
                                      ),
                                    ),
                                  ),
                                ),
                                RecentPastDeparturesExpansion(
                                  rawStopId: sid,
                                  bubbles: lines,
                                  schedule: scheduleIndex,
                                  onPastTripTimeChipTap:
                                      (c, past, bubble) =>
                                          openTripTimetableForRecentPastDeparture(
                                            c,
                                            schedule: scheduleIndex,
                                            lineeByComposite: lineeByComposite,
                                            rawStopId: sid,
                                            stopNameUi: stopUiEmpty,
                                            past: past,
                                            bubble: bubble,
                                          ),
                                ),
                              ],
                            );
                          }

                          final rawName = payload.stopNameRaw ?? '';
                          final stopUiPast =
                              rawName.isEmpty
                                  ? sid
                                  : transitStopNameForDisplay(rawName);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final u in upcoming) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: RichText(
                                          text: TextSpan(
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              height: 1.4,
                                              color: kRomagnaDarkGray,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            children: [
                                              TextSpan(text: u.lineLabel),
                                              TextSpan(
                                                text: ' ${u.secondaryLabel}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  height: 1.4,
                                                  fontWeight: FontWeight.w600,
                                                  color: kRomagnaDarkGray
                                                      .withValues(alpha: 0.45),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          u.towards,
                                          textAlign: TextAlign.end,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 13.5,
                                            height: 1.4,
                                            fontWeight: FontWeight.w600,
                                            color: kRomagnaDarkGray.withValues(
                                              alpha: 0.82,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      TransitScheduleTimeChip(
                                        timeLabel:
                                            u.dayPrefix.isEmpty
                                                ? u.clockLabel
                                                : '${u.dayPrefix}${u.clockLabel}',
                                        tint: kRomagnaPrimary,
                                        timeTextColor: transitChipTimeTextColor(
                                          kRomagnaPrimary,
                                        ),
                                        isPrenotazione: u.isPrenotazione,
                                        timeFontSize: 13.5,
                                        verticalPadding: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              RecentPastDeparturesExpansion(
                                rawStopId: sid,
                                bubbles: lines,
                                schedule: scheduleIndex,
                                onPastTripTimeChipTap:
                                    (c, past, bubble) =>
                                        openTripTimetableForRecentPastDeparture(
                                          c,
                                          schedule: scheduleIndex,
                                          lineeByComposite: lineeByComposite,
                                          rawStopId: sid,
                                          stopNameUi: stopUiPast,
                                          past: past,
                                          bubble: bubble,
                                        ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TransitLineBubbleChip extends StatelessWidget {
  const _TransitLineBubbleChip({
    required this.bubble,
    required this.extraurbanBg,
    this.onTap,
  });

  final StopTransitLineBubble bubble;
  final Color extraurbanBg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final urban = !bubble.isExtraurban;
    final isMetromareBubble = bubble.lineaLabel.trim().toLowerCase().contains(
      'metromare',
    );
    final urbanBaseColor = isMetromareBubble ? kMetromareRed : kRomagnaPrimary;
    final secondaryText = bubble.secondaryGrey ?? bubble.bacinoUpper;
    final bacinoColor =
        urban
            ? (isMetromareBubble
                ? urbanBaseColor.withValues(alpha: 0.55)
                : kRomagnaDarkGray.withValues(alpha: 0.38))
            : Colors.white.withValues(alpha: 0.55);
    final lineColor = urban ? urbanBaseColor : Colors.white;
    final bg = urban ? urbanBaseColor.withValues(alpha: 0.14) : extraurbanBg;

    final child = DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border:
            urban
                ? Border.all(
                  color: urbanBaseColor.withValues(alpha: 0.35),
                  width: 1,
                )
                : null,
      ),
      child: Align(
        alignment: Alignment.center,
        widthFactor: 1,
        heightFactor: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: RichText(
            softWrap: false,
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
            text: TextSpan(
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.0,
                color: lineColor,
              ),
              children: [
                TextSpan(text: bubble.lineaLabel),
                TextSpan(
                  text: ' $secondaryText',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                    color: bacinoColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: child,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Chip filtro nel foglio (selezionato: sfondo azzurro chiaro; altrimenti bordo grigio).
// -----------------------------------------------------------------------------
class _SheetFilterChip extends StatelessWidget {
  const _SheetFilterChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? kRomagnaPrimary.withValues(alpha: 0.14) : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.transparent : kSearchBorder,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? kRomagnaPrimary : kNavIconInactive,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? kRomagnaPrimary : kNavIconInactive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAddressSlotPickerDialog extends StatefulWidget {
  const _QuickAddressSlotPickerDialog({
    required this.title,
    required this.minSearchChars,
    required this.transitStops,
    required this.ferryStops,
    required this.priorityOriginResolver,
    required this.readCurrentLocationAsHit,
  });

  final String title;
  final int minSearchChars;
  final List<TransitStopPin> transitStops;
  final List<FerryStopPin> ferryStops;
  final LatLng Function() priorityOriginResolver;
  final Future<RomagnaAddressHit?> Function() readCurrentLocationAsHit;

  @override
  State<_QuickAddressSlotPickerDialog> createState() =>
      _QuickAddressSlotPickerDialogState();
}

class _QuickAddressSlotPickerDialogState
    extends State<_QuickAddressSlotPickerDialog> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  List<RomagnaAddressHit> _hits = [];
  int _searchSeq = 0;
  bool _currentLocationBusy = false;
  bool _searchBusy = false;

  InputDecoration _slotSearchDecoration() {
    return InputDecoration(
      hintText: 'Cerca indirizzo',
      hintStyle: GoogleFonts.inter(
        color: kRomagnaDarkGray.withValues(alpha: 0.45),
        fontSize: 15,
      ),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: const Icon(Icons.search_rounded),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: kRomagnaDarkGray.withValues(alpha: 0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: kRomagnaPrimary, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Future<void> _useCurrentLocation() async {
    if (_currentLocationBusy) return;
    setState(() => _currentLocationBusy = true);
    final hit = await widget.readCurrentLocationAsHit();
    if (!mounted) return;
    setState(() => _currentLocationBusy = false);
    if (hit != null) {
      Navigator.of(context).pop(_SlotPickOutcome(hit: hit));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _hits = [];
        _searchBusy = false;
      });
      return;
    }
    if (query.length < widget.minSearchChars) {
      setState(
        () =>
            _hits = busStopHitsForMapSearch(
              query,
              widget.transitStops,
              ferryStops: widget.ferryStops,
            ),
      );
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: kRomagnaSearchDebounceMs),
      () => _runSearch(query),
    );
  }

  Future<void> _runSearch(String queryAtSchedule) async {
    final seq = ++_searchSeq;
    setState(() => _searchBusy = true);
    final out = await searchRomagnaQuickAddresses(
      queryAtSchedule,
      transitStops: widget.transitStops,
      ferryStops: widget.ferryStops,
      priorityOrigin: widget.priorityOriginResolver(),
      minCharsRemote: widget.minSearchChars,
      maxTransitStops: 14,
      maxRemotePlaces: 20,
    );
    if (!mounted || seq != _searchSeq) return;
    if (_searchController.text.trim() != queryAtSchedule) return;
    setState(() {
      _hits = out;
      _searchBusy = false;
    });
  }

  void _popHit(RomagnaAddressHit hit) {
    Navigator.of(context).pop(_SlotPickOutcome(hit: hit));
  }

  Future<void> _openMapPickerFallback() async {
    final hit = await showDialog<RomagnaAddressHit>(
      context: context,
      builder:
          (_) => _QuickAddressMapPinPickerDialog(
            initialCenter: widget.priorityOriginResolver(),
          ),
    );
    if (!mounted || hit == null) return;
    _popHit(hit);
  }

  List<Widget> _buildQuickSearchResultChildren(List<RomagnaAddressHit> hits) {
    final addresses = <RomagnaAddressHit>[];
    final stops = <RomagnaAddressHit>[];
    final pois = <RomagnaAddressHit>[];
    for (final h in hits) {
      if (h.isBusStop || h.placeKind == RomagnaSearchPlaceKind.busStop) {
        stops.add(h);
      } else if (h.placeKind == RomagnaSearchPlaceKind.placeOfInterest) {
        pois.add(h);
      } else {
        addresses.add(h);
      }
    }

    Widget sectionTitle(String text) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: kRomagnaDarkGray.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    Widget tileFor(RomagnaAddressHit hit) {
      return ListTile(
        dense: true,
        title: romagnaSearchHitListTitle(hit),
        subtitle: romagnaSearchHitListSubtitle(hit),
        leading: romagnaSearchHitLeadingWidget(hit),
        onTap: () => _popHit(hit),
      );
    }

    final children = <Widget>[];
    void addSection(String title, List<RomagnaAddressHit> items) {
      if (items.isEmpty) return;
      if (children.isNotEmpty) {
        children.add(
          Divider(
            height: 1,
            thickness: 0.7,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        );
      }
      children.add(sectionTitle(title));
      for (final h in items) {
        children.add(tileFor(h));
      }
    }

    addSection('Indirizzi', addresses);
    addSection('Fermate', stops);
    addSection('Luoghi', pois);
    return children;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final dialogW = mq.width > 420 ? 400.0 : mq.width - 32;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        widget.title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          color: kRomagnaDarkGray,
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      content: SizedBox(
        width: dialogW,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.tonalIcon(
                onPressed: _currentLocationBusy ? null : _useCurrentLocation,
                icon:
                    _currentLocationBusy
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kRomagnaPrimary,
                          ),
                        )
                        : const Icon(Icons.my_location_rounded),
                label: Text(
                  'Posizione attuale',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  foregroundColor: kRomagnaDarkGray,
                  backgroundColor: kRomagnaPrimary.withValues(alpha: 0.14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Salva il punto in cui ti trovi ora',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  height: 1.3,
                  color: kRomagnaDarkGray.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: _onSearchChanged,
                autofocus: true,
                decoration: _slotSearchDecoration(),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    size: 16,
                    color: kRomagnaDarkGray.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Puoi cercare un indirizzo oppure una fermata (nome o codice).',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        height: 1.25,
                        color: kRomagnaDarkGray.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _openMapPickerFallback,
                  icon: const Icon(Icons.place_outlined, size: 18),
                  label: Text(
                    'Seleziona sulla mappa',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child:
                    _searchBusy
                        ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : _hits.isEmpty
                        ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _searchController.text.trim().length < 2
                                      ? 'Cerca e seleziona un risultato dall’elenco'
                                      : 'Nessun risultato preciso. Seleziona l’indirizzo direttamente sulla mappa.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: kRomagnaDarkGray.withValues(
                                      alpha: 0.55,
                                    ),
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                                if (_searchController.text.trim().length >=
                                    2) ...[
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: _openMapPickerFallback,
                                    icon: const Icon(
                                      Icons.place_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Seleziona sulla mappa',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                        : _GlassAutocompleteResults(
                          maxHeight: 220,
                          addTopPadding: false,
                          child: ListView(
                            children: _buildQuickSearchResultChildren(_hits),
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Annulla',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _QuickAddressMapPinPickerDialog extends StatefulWidget {
  const _QuickAddressMapPinPickerDialog({required this.initialCenter});

  final LatLng initialCenter;

  @override
  State<_QuickAddressMapPinPickerDialog> createState() =>
      _QuickAddressMapPinPickerDialogState();
}

class _QuickAddressMapPinPickerDialogState
    extends State<_QuickAddressMapPinPickerDialog> {
  final MapController _previewMapController = MapController();
  late LatLng _center;
  double _zoom = 16;
  bool _confirmBusy = false;

  @override
  void initState() {
    super.initState();
    _center =
        isValidMapLatLng(widget.initialCenter)
            ? widget.initialCenter
            : kRomagnaMapCenter;
  }

  Future<void> _confirm() async {
    if (_confirmBusy) return;
    setState(() => _confirmBusy = true);
    final rev = await reverseRomagnaPlace(_center);
    if (!mounted) return;
    final label =
        rev == null
            ? 'Punto selezionato sulla mappa'
            : '${rev.formatted} · punto selezionato sulla mappa';
    Navigator.of(context).pop(
      RomagnaAddressHit(
        label: label,
        point: _center,
        placeKind: RomagnaSearchPlaceKind.addressBuilding,
      ),
    );
  }

  void _zoomBy(double delta) {
    try {
      final cam = _previewMapController.camera;
      final baseCenter = isValidMapLatLng(cam.center) ? cam.center : _center;
      final nextZoom = (cam.zoom + delta).clamp(
        kRomagnaMapMinZoom,
        kRomagnaMapMaxZoom,
      );
      safeMapMove(_previewMapController, baseCenter, nextZoom);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        'Seleziona indirizzo sulla mappa',
        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
      contentPadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sposta la mappa e allinea il pin centrale al punto corretto, poi conferma.',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.35,
                color: kRomagnaDarkGray.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 260,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _previewMapController,
                      options: MapOptions(
                        initialCenter: _center,
                        initialZoom: _zoom,
                        minZoom: kRomagnaMapMinZoom,
                        maxZoom: kRomagnaMapMaxZoom,
                        onPositionChanged: (pos, _) {
                          final c = pos.center;
                          if (isValidMapLatLng(c)) {
                            setState(() {
                              _center = c;
                              _zoom = pos.zoom.isFinite ? pos.zoom : _zoom;
                            });
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: _kMapTileHot,
                          subdomains: _kMapTileSubdomainsOsmFr,
                          userAgentPackageName: 'RomagnaGO',
                          maxNativeZoom: 19,
                        ),
                      ],
                    ),
                    IgnorePointer(
                      child: Center(
                        child: Icon(
                          Icons.location_on_rounded,
                          size: 42,
                          color: kRomagnaPrimary,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Column(
                        children: [
                          _MapZoomButton(
                            icon: Icons.add,
                            onTap: () => _zoomBy(1),
                          ),
                          const SizedBox(height: 8),
                          _MapZoomButton(
                            icon: Icons.remove,
                            onTap: () => _zoomBy(-1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _confirmBusy ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Annulla',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
        FilledButton.icon(
          onPressed: _confirmBusy ? null : _confirm,
          icon:
              _confirmBusy
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Icon(Icons.check_rounded),
          label: Text(
            'Conferma indirizzo',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _QuickAddressIconPickerDialog extends StatefulWidget {
  const _QuickAddressIconPickerDialog({required this.initialTag});

  final String initialTag;

  @override
  State<_QuickAddressIconPickerDialog> createState() =>
      _QuickAddressIconPickerDialogState();
}

class _QuickAddressIconPickerDialogState
    extends State<_QuickAddressIconPickerDialog> {
  late String _selectedKey;

  @override
  void initState() {
    super.initState();
    _selectedKey = suggestQuickAddressIconKeyFromTag(widget.initialTag);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        'Scegli icona indirizzo',
        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
      contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suggerimento automatico selezionato in base al nome: puoi cambiarlo.',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.35,
                color: kRomagnaDarkGray.withValues(alpha: 0.58),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: kQuickAddressIconOptions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.25,
                ),
                itemBuilder: (context, index) {
                  final item = kQuickAddressIconOptions[index];
                  final selected = item.key == _selectedKey;
                  return Material(
                    color:
                        selected
                            ? kRomagnaPrimary.withValues(alpha: 0.14)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selectedKey = item.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                selected
                                    ? kRomagnaPrimary.withValues(alpha: 0.55)
                                    : kRomagnaDarkGray.withValues(alpha: 0.12),
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.icon,
                              color:
                                  selected ? kRomagnaPrimary : kRomagnaDarkGray,
                              size: 22,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                                color: kRomagnaDarkGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Annulla',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedKey),
          child: Text(
            'Conferma',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
