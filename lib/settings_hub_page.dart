// Hub impostazioni: bozza locale + Salva / Annulla sempre visibili.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_settings.dart';
import 'avvisi_cache.dart';
import 'infobus_realtime.dart';
import 'photon_romagna.dart';
import 'quick_addresses.dart';
import 'romagna_brand.dart';
import 'stop_visibility.dart';

typedef SettingsApplyCallback =
    Future<void> Function(
      AppSettings settings,
      QuickAddressesState quickAddresses,
    );

class SettingsHubPage extends StatefulWidget {
  const SettingsHubPage({
    super.key,
    required this.initialSettings,
    required this.initialQuickAddresses,
    required this.onApply,
  });

  final AppSettings initialSettings;
  final QuickAddressesState initialQuickAddresses;
  final SettingsApplyCallback onApply;

  @override
  State<SettingsHubPage> createState() => _SettingsHubPageState();
}

class _SettingsHubPageState extends State<SettingsHubPage> {
  late AppSettings _draft;
  late QuickAddressesState _quickDraft;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialSettings;
    _quickDraft = widget.initialQuickAddresses;
  }

  void _cancel() {
    AppSettingsScope.of(
      context,
    ).previewThemeAccent(widget.initialSettings.themeAccent);
    Navigator.of(context).pop();
  }

  void _setThemeAccent(AppThemeAccent accent) {
    setState(() => _draft = _draft.copyWith(themeAccent: accent));
    AppSettingsScope.of(context).previewThemeAccent(accent);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onApply(_draft, _quickDraft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impostazioni salvate',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Salvataggio non riuscito: $e',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearCaches() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              'Svuota cache',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            content: Text(
              'Procedere alle pulizia dei dati in tempo reale e degli avvisi? '
              'I dati relativi alle fermate non vengono eliminati.',
              style: GoogleFonts.inter(height: 1.35),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Svuota'),
              ),
            ],
          ),
    );
    if (ok != true || !mounted) return;
    clearInfobusRuntimeCache();
    clearAvvisiCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Cache svuotata.',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _resetAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              'Reset impostazioni',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            content: Text(
              'Tutte le impostazioni torneranno ai valori predefiniti. '
              'Gli indirizzi rapidi non vengono modificati.',
              style: GoogleFonts.inter(height: 1.35),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Reset'),
              ),
            ],
          ),
    );
    if (ok != true || !mounted) return;
    setState(() => _draft = AppSettings.defaults);
    AppSettingsScope.of(
      context,
    ).previewThemeAccent(AppSettings.defaults.themeAccent);
  }

  void _patch(AppSettings Function(AppSettings s) fn) {
    setState(() => _draft = fn(_draft));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Impostazioni',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                _sectionTitle('Mappa e TPL'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 18, 0, 4),
                  child: Text(
                    'Fermate visibili sulla mappa',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: kRomagnaDarkGray,
                      fontSize: 16,
                    ),
                  ),
                ),
                ...StopVisibilityOption.values.map(
                  (o) => RadioListTile<StopVisibilityOption>(
                    value: o,
                    groupValue: _draft.stopVisibility,
                    controlAffinity: ListTileControlAffinity.trailing,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: const VisualDensity(
                      horizontal: 0,
                      vertical: -4,
                    ),
                    title: Text(
                      stopVisibilityLabel(o),
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    onChanged:
                        (v) =>
                            v == null
                                ? null
                                : _patch((s) => s.copyWith(stopVisibility: v)),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text(
                    'Solo fermate extraurbane',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Mostra solo le fermate in cui transitano linee extraurbane',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  contentPadding: EdgeInsets.zero,
                  value: _draft.extraurbanStopsOnly,
                  activeColor: kRomagnaPrimary,
                  onChanged:
                      (v) => _patch((s) => s.copyWith(extraurbanStopsOnly: v)),
                ),
                SwitchListTile(
                  title: Text(
                    'Mostra fermate bus',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  contentPadding: EdgeInsets.zero,
                  value: _draft.showBusStops,
                  activeColor: kRomagnaPrimary,
                  onChanged: (v) => _patch((s) => s.copyWith(showBusStops: v)),
                ),
                SwitchListTile(
                  title: Text(
                    'Fermate traghetto Ravenna',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  contentPadding: EdgeInsets.zero,
                  value: _draft.showFerryRavennaStops,
                  activeColor: kRomagnaPrimary,
                  onChanged:
                      (v) =>
                          _patch((s) => s.copyWith(showFerryRavennaStops: v)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Fermate Metromare',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  trailing: _outlinedDropdown<MetromareMapFilter>(
                    value: _draft.metromareFilter,
                    items:
                        MetromareMapFilter.values
                            .map(
                              (f) => DropdownMenuItem(
                                value: f,
                                child: Text(
                                  f.label,
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (v) =>
                            v == null
                                ? null
                                : _patch((s) => s.copyWith(metromareFilter: v)),
                  ),
                ),
                const Divider(height: 20),
                _sectionTitle('Ricerca'),
                ListTile(
                  contentPadding: EdgeInsets.fromLTRB(0, 6, 0, 2),
                  title: Text(
                    'Risultati di ricerca',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Mostra fino a ${_draft.mapSearchMaxResults} fermate nella ricerca',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: kRomagnaDarkGray.withValues(alpha: 0.58),
                    ),
                  ),
                  trailing: _outlinedDropdown<int>(
                    value: _draft.mapSearchMaxResults,
                    items:
                        [3, 5, 8]
                            .map(
                              (n) => DropdownMenuItem(
                                value: n,
                                child: Text(
                                  '$n',
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (v) =>
                            v == null
                                ? null
                                : _patch(
                                  (s) => s.copyWith(mapSearchMaxResults: v),
                                ),
                  ),
                ),
                SwitchListTile(
                  title: Text(
                    'Priorità fermate nelle vicinanze',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Mostra prima le fermate più vicine \nnei risultati di ricerca',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: kRomagnaDarkGray.withValues(alpha: 0.6),
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  value: _draft.priorityNearbyStopsInSearch,
                  activeColor: kRomagnaPrimary,
                  onChanged:
                      (v) => _patch(
                        (s) => s.copyWith(priorityNearbyStopsInSearch: v),
                      ),
                ),
                const Divider(height: 20),
                _sectionTitle('Mappa e aspetto'),
                ListTile(
                  contentPadding: EdgeInsets.fromLTRB(0, 6, 0, 2),
                  title: Text(
                    'Stile mappa all\'avvio',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _draft.startupMapStyle.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: kRomagnaDarkGray.withValues(alpha: 0.58),
                    ),
                  ),
                  trailing: _outlinedDropdown<AppStartupMapStyle>(
                    value: _draft.startupMapStyle,
                    items:
                        AppStartupMapStyle.values
                            .map(
                              (st) => DropdownMenuItem(
                                value: st,
                                child: Text(
                                  st.label,
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (v) =>
                            v == null
                                ? null
                                : _patch((s) => s.copyWith(startupMapStyle: v)),
                  ),
                ),
                SwitchListTile(
                  title: Text(
                    'Tema scuro',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  contentPadding: EdgeInsets.fromLTRB(0, 0, 0, 2),
                  value: _draft.darkTheme,
                  activeColor: kRomagnaPrimary,
                  onChanged: (v) => _patch((s) => s.copyWith(darkTheme: v)),
                ),
                SwitchListTile(
                  title: Text(
                    'Mappa Black con tema scuro',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Con tema scuro usa sempre la mappa Black',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: kRomagnaDarkGray.withValues(alpha: 0.6),
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  value: _draft.forceBlackMapWithDarkTheme,
                  activeColor: kRomagnaPrimary,
                  onChanged:
                      (v) => _patch(
                        (s) => s.copyWith(forceBlackMapWithDarkTheme: v),
                      ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.text_fields_outlined,
                    color: kRomagnaPrimary,
                  ),
                  title: Text(
                    'Dimensione testo',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _draft.textSizeScale.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: kRomagnaDarkGray.withValues(alpha: 0.58),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<AppTextSizeScale>(
                    segments:
                        AppTextSizeScale.values
                            .map(
                              (t) => ButtonSegment(
                                value: t,
                                label: Text(
                                  t.label,
                                  style: GoogleFonts.inter(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
                    selected: {_draft.textSizeScale},
                    onSelectionChanged:
                        (s) =>
                            _patch((st) => st.copyWith(textSizeScale: s.first)),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Colore tema',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: kRomagnaDarkGray,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (
                            var i = 0;
                            i < AppThemeAccent.values.length;
                            i++
                          ) ...[
                            if (i > 0) const SizedBox(width: 10),
                            _ThemeAccentSwatch(
                              accent: AppThemeAccent.values[i],
                              selected:
                                  _draft.themeAccent ==
                                  AppThemeAccent.values[i],
                              onTap:
                                  () =>
                                      _setThemeAccent(AppThemeAccent.values[i]),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 20),
                _sectionTitle('Indirizzi rapidi'),
                _QuickAddressesEditor(
                  state: _quickDraft,
                  onChanged: (s) => setState(() => _quickDraft = s),
                ),
                const Divider(height: 20),
                _sectionTitle('Avvisi'),
                ListTile(
                  contentPadding: EdgeInsets.fromLTRB(0, 6, 0, 2),
                  title: Text(
                    'Intervallo aggiorn. avvisi',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  trailing: _outlinedDropdown<AvvisiRefreshInterval>(
                    value: _draft.avvisiRefreshInterval,
                    items:
                        AvvisiRefreshInterval.values
                            .map(
                              (iv) => DropdownMenuItem(
                                value: iv,
                                child: Text(
                                  iv.label,
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (v) =>
                            v == null
                                ? null
                                : _patch(
                                  (s) => s.copyWith(avvisiRefreshInterval: v),
                                ),
                  ),
                ),
                SwitchListTile(
                  title: Text(
                    'Priorità avvisi di sciopero',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Gli avvisi di sciopero compaiono sempre in cima',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: kRomagnaDarkGray.withValues(alpha: 0.6),
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  value: _draft.prioritizeScioperoAvvisi,
                  activeColor: kRomagnaPrimary,
                  onChanged:
                      (v) => _patch(
                        (s) => s.copyWith(prioritizeScioperoAvvisi: v),
                      ),
                ),
                const Divider(height: 20),
                _sectionTitle('Dati'),
                ListTile(
                  contentPadding: EdgeInsets.fromLTRB(0, 6, 0, 2),
                  leading: Icon(
                    Icons.cleaning_services_outlined,
                    color: kRomagnaPrimary,
                  ),
                  title: Text(
                    'Svuota cache',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Dati in tempo reale e avvisi',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: kRomagnaDarkGray.withValues(alpha: 0.6),
                    ),
                  ),
                  onTap: _clearCaches,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.restart_alt_rounded,
                    color: kRomagnaPrimary,
                  ),
                  title: Text(
                    'Reset impostazioni',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Ripristina i valori predefiniti',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: kRomagnaDarkGray.withValues(alpha: 0.6),
                    ),
                  ),
                  onTap: _resetAll,
                ),
                const SizedBox(height: 64),
              ],
            ),
          ),
          Material(
            elevation: 8,
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _cancel,
                        child: Text(
                          'Annulla',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child:
                            _saving
                                ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Text(
                                  'Salva',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
    child: Text(
      t,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: kRomagnaPrimary,
      ),
    ),
  );

  Widget _outlinedDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kRomagnaDarkGray.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            isDense: true,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: kRomagnaDarkGray.withValues(alpha: 0.7),
            ),
            style: GoogleFonts.inter(fontSize: 13, color: kRomagnaDarkGray),
          ),
        ),
      ),
    );
  }
}

class _QuickAddressesEditor extends StatelessWidget {
  const _QuickAddressesEditor({required this.state, required this.onChanged});

  final QuickAddressesState state;
  final ValueChanged<QuickAddressesState> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget slotRow(
      String label,
      RomagnaAddressHit? hit,
      VoidCallback onEdit,
      VoidCallback onClear,
    ) {
      return ListTile(
        title: Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          hit == null ? 'Non impostato' : romagnaHitDisplayLine(hit),
          style: GoogleFonts.inter(
            fontSize: 13,
            color: kRomagnaDarkGray.withValues(alpha: 0.65),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hit != null)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: onClear,
              ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
            ),
          ],
        ),
      );
    }

    Future<void> editSlot({
      required String title,
      required RomagnaAddressHit? initial,
      required void Function(RomagnaAddressHit? hit) apply,
    }) async {
      final ctrl = TextEditingController(
        text: initial == null ? '' : romagnaHitDisplayLine(initial),
      );
      final hit = await showDialog<RomagnaAddressHit?>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(
                title,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              content: TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: 'Via, numero, comune…',
                  hintStyle: GoogleFonts.inter(),
                ),
                autofocus: true,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () async {
                    final q = ctrl.text.trim();
                    if (q.length < 2) {
                      Navigator.pop(ctx, null);
                      return;
                    }
                    final list = await searchRomagnaAddresses(q);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx, list.isEmpty ? null : list.first);
                  },
                  child: const Text('Cerca'),
                ),
              ],
            ),
      );
      if (!context.mounted) return;
      apply(hit);
    }

    return Column(
      children: [
        slotRow(
          'Casa',
          state.home,
          () => editSlot(
            title: 'Indirizzo Casa',
            initial: state.home,
            apply: (h) => onChanged(state.copyWith(home: h)),
          ),
          () => onChanged(state.copyWith(clearHome: true)),
        ),
        slotRow(
          'Lavoro',
          state.work,
          () => editSlot(
            title: 'Indirizzo Lavoro',
            initial: state.work,
            apply: (h) => onChanged(state.copyWith(work: h)),
          ),
          () => onChanged(state.copyWith(clearWork: true)),
        ),
        for (final e in state.extras)
          ListTile(
            title: Text(
              e.tag,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              romagnaHitDisplayLine(e.hit),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: kRomagnaDarkGray.withValues(alpha: 0.65),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () {
                final next = state.extras.where((x) => x.id != e.id).toList();
                onChanged(state.copyWith(extras: next));
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final tagCtrl = TextEditingController();
                final hit = await showDialog<RomagnaAddressHit?>(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        title: Text(
                          'Nuovo indirizzo rapido',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: tagCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Tag',
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Annulla'),
                          ),
                          FilledButton(
                            onPressed: () async {
                              final q = tagCtrl.text.trim();
                              if (q.length < 2) return;
                              final list = await searchRomagnaAddresses(q);
                              if (!ctx.mounted) return;
                              Navigator.pop(
                                ctx,
                                list.isEmpty ? null : list.first,
                              );
                            },
                            child: const Text('Cerca indirizzo'),
                          ),
                        ],
                      ),
                );
                if (hit == null || !context.mounted) return;
                final tag =
                    tagCtrl.text.trim().isEmpty ? 'Extra' : tagCtrl.text.trim();
                final id = DateTime.now().millisecondsSinceEpoch.toString();
                onChanged(
                  state.copyWith(
                    extras: [
                      ...state.extras,
                      NamedQuickAddress(id: id, tag: tag, hit: hit),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Aggiungi indirizzo',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeAccentSwatch extends StatelessWidget {
  const _ThemeAccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AppThemeAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = themeAccentPrimary(accent);
    final light = themeAccentPrimaryLight(accent);
    return Semantics(
      button: true,
      selected: selected,
      label: accent.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    selected
                        ? kRomagnaDarkGray.withValues(alpha: 0.88)
                        : kRomagnaDarkGray.withValues(alpha: 0.14),
                width: selected ? 2.2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.5),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [dark, light],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
