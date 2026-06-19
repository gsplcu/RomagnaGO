import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'photon_romagna.dart';

/// Tap su marker indirizzo rapido in mappa → sheet dettaglio / azioni.
class QuickAddressMarkerTapDetails {
  const QuickAddressMarkerTapDetails({
    required this.title,
    required this.icon,
    required this.hit,
    required this.slotKind,
    this.namedExtra,
  });

  final String title;
  final IconData icon;
  final RomagnaAddressHit hit;

  /// Per [QuickAddressSlotKind.extra], [namedExtra] è valorizzato.
  final QuickAddressSlotKind slotKind;
  final NamedQuickAddress? namedExtra;
}

enum QuickAddressSlotKind { home, work, extra }

const String kQuickAddressesPrefsKey = 'quick_addresses_v2';

/// Indirizzo rapido con etichetta scelta dall'utente (Hotel, Negozio, …).
class NamedQuickAddress {
  const NamedQuickAddress({
    required this.id,
    required this.tag,
    required this.hit,
    this.iconKey = kQuickAddressIconPin,
  });

  final String id;
  final String tag;
  final RomagnaAddressHit hit;
  final String iconKey;

  NamedQuickAddress copyWith({
    String? id,
    String? tag,
    RomagnaAddressHit? hit,
    String? iconKey,
  }) => NamedQuickAddress(
    id: id ?? this.id,
    tag: tag ?? this.tag,
    hit: hit ?? this.hit,
    iconKey: iconKey ?? this.iconKey,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tag': tag,
    'hit': hit.toJson(),
    'iconKey': iconKey,
  };

  static NamedQuickAddress fromJson(Map<String, dynamic> m) =>
      NamedQuickAddress(
        id: m['id'] as String? ?? '',
        tag: m['tag'] as String? ?? '',
        hit: RomagnaAddressHit.fromJson(
          Map<String, dynamic>.from(m['hit'] as Map? ?? {}),
        ),
        iconKey:
            quickAddressIconKeyNormalized(
              m['iconKey'] as String?,
              fallbackTag: m['tag'] as String? ?? '',
            ),
      );
}

const String kQuickAddressIconPin = 'pin';

const List<({String key, String label, IconData icon})> kQuickAddressIconOptions = [
  (key: 'pin', label: 'Generico', icon: Icons.place_outlined),
  (key: 'hotel', label: 'Hotel', icon: Icons.hotel_rounded),
  (key: 'fitness', label: 'Palestra', icon: Icons.fitness_center_rounded),
  (key: 'health', label: 'Salute', icon: Icons.local_hospital_rounded),
  (key: 'cinema', label: 'Cinema', icon: Icons.movie_rounded),
  (key: 'food', label: 'Ristorante', icon: Icons.restaurant_rounded),
  (key: 'coffee', label: 'Bar', icon: Icons.local_cafe_rounded),
  (key: 'shopping', label: 'Shopping', icon: Icons.shopping_bag_rounded),
  (key: 'school', label: 'Scuola', icon: Icons.school_rounded),
  (key: 'office', label: 'Ufficio', icon: Icons.business_center_rounded),
  (key: 'transport', label: 'Trasporti', icon: Icons.train_rounded),
  (key: 'home_alt', label: 'Casa secondaria', icon: Icons.home_rounded),
  (key: 'star', label: 'Preferito', icon: Icons.star_rounded),
];

IconData quickAddressIconDataForKey(String? key) {
  final normalized = quickAddressIconKeyNormalized(key);
  for (final o in kQuickAddressIconOptions) {
    if (o.key == normalized) return o.icon;
  }
  return Icons.place_outlined;
}

String quickAddressIconKeyNormalized(String? key, {String fallbackTag = ''}) {
  final raw = (key ?? '').trim().toLowerCase();
  final known = kQuickAddressIconOptions.any((o) => o.key == raw);
  if (known) return raw;
  return suggestQuickAddressIconKeyFromTag(fallbackTag);
}

String suggestQuickAddressIconKeyFromTag(String tag) {
  final t =
      tag
          .toLowerCase()
          .replaceAll(RegExp(r"[’'`´]"), '')
          .replaceAll(RegExp(r'[^a-z0-9àèéìòù\\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
  if (t.isEmpty) return kQuickAddressIconPin;

  bool hasAny(List<String> words) => words.any((w) => t.contains(w));
  if (hasAny([
    'hotel',
    'albergo',
    'pensione',
    'b&b',
    'bed and breakfast',
    'ostello',
    'residence',
  ])) {
    return 'hotel';
  }
  if (hasAny([
    'palestra',
    'gym',
    'fitness',
    'crossfit',
    'yoga',
    'pilates',
  ])) {
    return 'fitness';
  }
  if (hasAny([
    'dottore',
    'medico',
    'infermiere',
    'cup',
    'ospedale',
    'clinica',
    'farmacia',
    'ambulatorio',
  ])) {
    return 'health';
  }
  if (hasAny(['cinema', 'multisala', 'movie', 'film'])) return 'cinema';
  if (hasAny(['ristorante', 'trattoria', 'osteria', 'pizzeria'])) return 'food';
  if (hasAny(['bar', 'cafe', 'caffè', 'caffe'])) return 'coffee';
  if (hasAny(['negozio', 'shopping', 'market', 'supermercato', 'centro commerciale'])) {
    return 'shopping';
  }
  if (hasAny(['scuola', 'liceo', 'istituto', 'universita', 'università'])) {
    return 'school';
  }
  if (hasAny(['ufficio', 'lavoro', 'studio'])) return 'office';
  if (hasAny(['stazione', 'treno', 'bus', 'autobus', 'metro', 'aeroporto'])) {
    return 'transport';
  }
  if (hasAny(['casa'])) return 'home_alt';
  return kQuickAddressIconPin;
}

/// Fino a 5 indirizzi: Casa, Lavoro e al massimo tre con tag personalizzato.
class QuickAddressesState {
  const QuickAddressesState({
    this.home,
    this.work,
    this.extras = const [],
  });

  final RomagnaAddressHit? home;
  final RomagnaAddressHit? work;
  final List<NamedQuickAddress> extras;

  static const int kMaxTotal = 5;
  static const int kMaxExtras = 3;

  int get savedCount =>
      (home != null ? 1 : 0) + (work != null ? 1 : 0) + extras.length;

  bool get canAddMore => savedCount < kMaxTotal;

  QuickAddressesState copyWith({
    RomagnaAddressHit? home,
    bool clearHome = false,
    RomagnaAddressHit? work,
    bool clearWork = false,
    List<NamedQuickAddress>? extras,
  }) {
    return QuickAddressesState(
      home: clearHome ? null : (home ?? this.home),
      work: clearWork ? null : (work ?? this.work),
      extras: extras ?? this.extras,
    );
  }

  QuickAddressesState withExtra(NamedQuickAddress n) {
    if (extras.length >= kMaxExtras || !canAddMore) return this;
    return QuickAddressesState(home: home, work: work, extras: [...extras, n]);
  }

  QuickAddressesState removeExtraById(String id) {
    return QuickAddressesState(
      home: home,
      work: work,
      extras: extras.where((e) => e.id != id).toList(growable: false),
    );
  }

  QuickAddressesState replaceExtra(NamedQuickAddress n) {
    return QuickAddressesState(
      home: home,
      work: work,
      extras:
          extras
              .map((e) => e.id == n.id ? n : e)
              .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'home': home?.toJson(),
    'work': work?.toJson(),
    'extras': extras.map((e) => e.toJson()).toList(),
  };

  static QuickAddressesState fromJson(Map<String, dynamic> m) {
    final h = m['home'];
    final w = m['work'];
    final ex = m['extras'];
    return QuickAddressesState(
      home:
          h is Map<String, dynamic>
              ? RomagnaAddressHit.fromJson(h)
              : null,
      work:
          w is Map<String, dynamic>
              ? RomagnaAddressHit.fromJson(w)
              : null,
      extras:
          ex is List
              ? ex
                  .whereType<Map>()
                  .map(
                    (e) => NamedQuickAddress.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
                  )
                  .toList(growable: false)
              : const [],
    );
  }

  static const QuickAddressesState empty = QuickAddressesState();
}

Future<QuickAddressesState> loadQuickAddressesFromPrefs() async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString(kQuickAddressesPrefsKey);
  if (raw == null || raw.isEmpty) return QuickAddressesState.empty;
  try {
    final d = jsonDecode(raw);
    if (d is! Map<String, dynamic>) return QuickAddressesState.empty;
    return QuickAddressesState.fromJson(d);
  } catch (_) {
    return QuickAddressesState.empty;
  }
}

Future<void> saveQuickAddressesToPrefs(QuickAddressesState s) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(kQuickAddressesPrefsKey, jsonEncode(s.toJson()));
}
