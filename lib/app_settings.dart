// Preferenze app: persistenza SharedPreferences e notifica ai listener.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'stop_visibility.dart';
import 'romagna_brand.dart' show AppThemeAccent, applyRomagnaThemeAccent;

const String kAppSettingsPrefsKey = 'app_settings_v1';

/// Stile mappa predefinito all'avvio (tile layer).
enum AppStartupMapStyle {
  standard,
  satellite,
  cyclOsm,
  white,
  black,
}

/// Visibilità fermate Metromare (ID TRC…) sulla mappa.
enum MetromareMapFilter {
  show,
  hide,
  onlyMetromare,
}

/// Dimensione testo UI (1.0 = dimensione attuale dell'app, mai superiore).
enum AppTextSizeScale {
  small,
  medium,
  large,
}

/// Intervallo refresh elenco avvisi (parsing InfoBus).
enum AvvisiRefreshInterval {
  minutes10,
  minutes30,
  hour1,
}

extension AvvisiRefreshIntervalX on AvvisiRefreshInterval {
  Duration get duration => switch (this) {
    AvvisiRefreshInterval.minutes10 => const Duration(minutes: 10),
    AvvisiRefreshInterval.minutes30 => const Duration(minutes: 30),
    AvvisiRefreshInterval.hour1 => const Duration(hours: 1),
  };

  String get label => switch (this) {
    AvvisiRefreshInterval.minutes10 => '10 minuti',
    AvvisiRefreshInterval.minutes30 => '30 minuti',
    AvvisiRefreshInterval.hour1 => '1 ora',
  };
}

extension AppTextSizeScaleX on AppTextSizeScale {
  double get factor => switch (this) {
    AppTextSizeScale.small => 0.88,
    AppTextSizeScale.medium => 0.94,
    AppTextSizeScale.large => 1.0,
  };

  String get label => switch (this) {
    AppTextSizeScale.small => 'Piccolo',
    AppTextSizeScale.medium => 'Medio',
    AppTextSizeScale.large => 'Grande',
  };
}

extension AppStartupMapStyleX on AppStartupMapStyle {
  String get label => switch (this) {
    AppStartupMapStyle.standard => 'Standard',
    AppStartupMapStyle.satellite => 'Satellite',
    AppStartupMapStyle.cyclOsm => 'CyclOSM',
    AppStartupMapStyle.white => 'White',
    AppStartupMapStyle.black => 'Black',
  };

}

extension MetromareMapFilterX on MetromareMapFilter {
  String get label => switch (this) {
    MetromareMapFilter.show => 'On',
    MetromareMapFilter.hide => 'Off',
    MetromareMapFilter.onlyMetromare => 'Solo Metromare',
  };
}

@immutable
class AppSettings {
  const AppSettings({
    this.stopVisibility = StopVisibilityOption.all,
    this.extraurbanStopsOnly = false,
    this.showBusStops = true,
    this.showFerryRavennaStops = true,
    this.metromareFilter = MetromareMapFilter.show,
    this.mapSearchMaxResults = 3,
    this.priorityNearbyStopsInSearch = true,
    this.startupMapStyle = AppStartupMapStyle.standard,
    this.darkTheme = false,
    this.forceBlackMapWithDarkTheme = true,
    this.avvisiRefreshInterval = AvvisiRefreshInterval.hour1,
    this.prioritizeScioperoAvvisi = true,
    this.textSizeScale = AppTextSizeScale.large,
    this.themeAccent = AppThemeAccent.blue,
  });

  final StopVisibilityOption stopVisibility;
  final bool extraurbanStopsOnly;
  final bool showBusStops;
  final bool showFerryRavennaStops;
  final MetromareMapFilter metromareFilter;
  final int mapSearchMaxResults;
  final bool priorityNearbyStopsInSearch;
  final AppStartupMapStyle startupMapStyle;
  final bool darkTheme;
  final bool forceBlackMapWithDarkTheme;
  final AvvisiRefreshInterval avvisiRefreshInterval;
  final bool prioritizeScioperoAvvisi;
  final AppTextSizeScale textSizeScale;
  final AppThemeAccent themeAccent;

  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    StopVisibilityOption? stopVisibility,
    bool? extraurbanStopsOnly,
    bool? showBusStops,
    bool? showFerryRavennaStops,
    MetromareMapFilter? metromareFilter,
    int? mapSearchMaxResults,
    bool? priorityNearbyStopsInSearch,
    AppStartupMapStyle? startupMapStyle,
    bool? darkTheme,
    bool? forceBlackMapWithDarkTheme,
    AvvisiRefreshInterval? avvisiRefreshInterval,
    bool? prioritizeScioperoAvvisi,
    AppTextSizeScale? textSizeScale,
    AppThemeAccent? themeAccent,
  }) => AppSettings(
    stopVisibility: stopVisibility ?? this.stopVisibility,
    extraurbanStopsOnly: extraurbanStopsOnly ?? this.extraurbanStopsOnly,
    showBusStops: showBusStops ?? this.showBusStops,
    showFerryRavennaStops: showFerryRavennaStops ?? this.showFerryRavennaStops,
    metromareFilter: metromareFilter ?? this.metromareFilter,
    mapSearchMaxResults: mapSearchMaxResults ?? this.mapSearchMaxResults,
    priorityNearbyStopsInSearch:
        priorityNearbyStopsInSearch ?? this.priorityNearbyStopsInSearch,
    startupMapStyle: startupMapStyle ?? this.startupMapStyle,
    darkTheme: darkTheme ?? this.darkTheme,
    forceBlackMapWithDarkTheme:
        forceBlackMapWithDarkTheme ?? this.forceBlackMapWithDarkTheme,
    avvisiRefreshInterval: avvisiRefreshInterval ?? this.avvisiRefreshInterval,
    prioritizeScioperoAvvisi:
        prioritizeScioperoAvvisi ?? this.prioritizeScioperoAvvisi,
    textSizeScale: textSizeScale ?? this.textSizeScale,
    themeAccent: themeAccent ?? this.themeAccent,
  );

  Map<String, dynamic> toJson() => {
    'stopVisibility': stopVisibility.index,
    'extraurbanStopsOnly': extraurbanStopsOnly,
    'showBusStops': showBusStops,
    'showFerryRavennaStops': showFerryRavennaStops,
    'metromareFilter': metromareFilter.index,
    'mapSearchMaxResults': mapSearchMaxResults,
    'priorityNearbyStopsInSearch': priorityNearbyStopsInSearch,
    'startupMapStyle': startupMapStyle.index,
    'darkTheme': darkTheme,
    'forceBlackMapWithDarkTheme': forceBlackMapWithDarkTheme,
    'avvisiRefreshInterval': avvisiRefreshInterval.index,
    'prioritizeScioperoAvvisi': prioritizeScioperoAvvisi,
    'textSizeScale': textSizeScale.index,
    'themeAccent': themeAccent.index,
  };

  static AppSettings fromJson(Map<String, dynamic> m) {
    int idx(String key, int max, int fallback) {
      final v = m[key];
      if (v is int && v >= 0 && v <= max) return v;
      return fallback;
    }

    var searchMax = m['mapSearchMaxResults'];
    if (searchMax is! int || ![3, 5, 8].contains(searchMax)) {
      searchMax = 3;
    }

    return AppSettings(
      stopVisibility: StopVisibilityOption.values[idx(
        'stopVisibility',
        StopVisibilityOption.values.length - 1,
        0,
      )],
      extraurbanStopsOnly: m['extraurbanStopsOnly'] as bool? ?? false,
      showBusStops: m['showBusStops'] as bool? ?? true,
      showFerryRavennaStops: m['showFerryRavennaStops'] as bool? ?? true,
      metromareFilter: MetromareMapFilter.values[idx(
        'metromareFilter',
        MetromareMapFilter.values.length - 1,
        0,
      )],
      mapSearchMaxResults: searchMax,
      priorityNearbyStopsInSearch:
          m['priorityNearbyStopsInSearch'] as bool? ?? true,
      startupMapStyle: AppStartupMapStyle.values[idx(
        'startupMapStyle',
        AppStartupMapStyle.values.length - 1,
        0,
      )],
      darkTheme: m['darkTheme'] as bool? ?? false,
      forceBlackMapWithDarkTheme:
          m['forceBlackMapWithDarkTheme'] as bool? ?? true,
      avvisiRefreshInterval: AvvisiRefreshInterval.values[idx(
        'avvisiRefreshInterval',
        AvvisiRefreshInterval.values.length - 1,
        2,
      )],
      prioritizeScioperoAvvisi: m['prioritizeScioperoAvvisi'] as bool? ?? true,
      textSizeScale: AppTextSizeScale.values[idx(
        'textSizeScale',
        AppTextSizeScale.values.length - 1,
        2,
      )],
      themeAccent: AppThemeAccent.values[idx(
        'themeAccent',
        AppThemeAccent.values.length - 1,
        0,
      )],
    );
  }

}

Future<AppSettings> loadAppSettings() async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString(kAppSettingsPrefsKey);
  if (raw == null || raw.isEmpty) return AppSettings.defaults;
  try {
    final d = jsonDecode(raw);
    if (d is Map<String, dynamic>) return AppSettings.fromJson(d);
  } catch (_) {}
  return AppSettings.defaults;
}

Future<void> saveAppSettings(AppSettings s) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(kAppSettingsPrefsKey, jsonEncode(s.toJson()));
}

Future<void> clearAppSettingsPrefs() async {
  final p = await SharedPreferences.getInstance();
  await p.remove(kAppSettingsPrefsKey);
}

/// Controller globale: carica, applica e notifica senza restart app.
class AppSettingsController extends ChangeNotifier {
  AppSettings _value = AppSettings.defaults;
  bool _loaded = false;

  AppSettings get value => _value;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _value = await loadAppSettings();
    applyRomagnaThemeAccent(_value.themeAccent);
    _loaded = true;
    notifyListeners();
  }

  Future<void> apply(AppSettings next) async {
    _value = next;
    applyRomagnaThemeAccent(next.themeAccent);
    await saveAppSettings(next);
    notifyListeners();
  }

  /// Anteprima colore tema (es. pallini in Impostazioni) senza salvare le preferenze.
  void previewThemeAccent(AppThemeAccent accent) {
    applyRomagnaThemeAccent(accent);
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    await apply(AppSettings.defaults);
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettingsController> {
  const AppSettingsScope({
    super.key,
    required AppSettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppSettingsController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'AppSettingsScope non trovato');
    return scope!.notifier!;
  }

  static AppSettings watch(BuildContext context) => of(context).value;
}

bool isMetromareStopId(String stopId) =>
    stopId.trim().toUpperCase().startsWith('TRC');
