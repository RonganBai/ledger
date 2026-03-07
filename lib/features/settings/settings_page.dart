import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/settings.dart';
import '../../app/theme.dart';
import '../../data/db/app_database.dart';
import 'settings_texts.dart';
import '../../services/cloud_bill_sync_service.dart';
import '../../ui/pet/pet_config.dart';
import 'import_export_service.dart';

enum QuickActionKey {
  stats,
  history,
  categories,
  settings,
  switchAccount,
  manageAccounts,
  recurring,
  analysis,
  externalImport,
}

String qaLabel(BuildContext context, QuickActionKey key) {
  switch (key) {
    case QuickActionKey.stats:
      return st(context, 'Stats');
    case QuickActionKey.history:
      return st(context, 'History');
    case QuickActionKey.categories:
      return st(context, 'Categories');
    case QuickActionKey.settings:
      return st(context, 'Settings');
    case QuickActionKey.switchAccount:
      return st(context, 'Switch Account');
    case QuickActionKey.manageAccounts:
      return st(context, 'Manage Accounts');
    case QuickActionKey.recurring:
      return st(context, 'Recurring');
    case QuickActionKey.analysis:
      return st(context, 'Analysis');
    case QuickActionKey.externalImport:
      return st(context, 'External Import');
  }
}

IconData qaIcon(QuickActionKey key) {
  switch (key) {
    case QuickActionKey.stats:
      return Icons.bar_chart_rounded;
    case QuickActionKey.history:
      return Icons.history_rounded;
    case QuickActionKey.categories:
      return Icons.category_rounded;
    case QuickActionKey.settings:
      return Icons.settings_rounded;
    case QuickActionKey.switchAccount:
      return Icons.swap_horiz_rounded;
    case QuickActionKey.manageAccounts:
      return Icons.account_balance_wallet_rounded;
    case QuickActionKey.recurring:
      return Icons.repeat_rounded;
    case QuickActionKey.analysis:
      return Icons.insights_rounded;
    case QuickActionKey.externalImport:
      return Icons.file_upload_rounded;
  }
}

String themeStyleLabel(BuildContext context, AppThemeStyle style) {
  switch (style) {
    case AppThemeStyle.indigo:
      return st(context, 'Indigo');
    case AppThemeStyle.forest:
      return st(context, 'Forest');
    case AppThemeStyle.sunset:
      return st(context, 'Sunset');
    case AppThemeStyle.ocean:
      return st(context, 'Ocean');
  }
}

class SettingsPage extends StatefulWidget {
  final AppDatabase db;
  final int accountId;
  final VoidCallback? onToggleLocale;
  final bool isDarkMode;
  final VoidCallback? onToggleThemeMode;
  final AppThemeStyle activeThemeStyle;
  final ValueChanged<AppThemeStyle>? onThemeStyleChanged;
  final String? themeBackgroundImagePath;
  final ValueChanged<String?>? onThemeBackgroundImageChanged;
  final double themeBackgroundMist;
  final ValueChanged<double>? onThemeBackgroundMistChanged;

  const SettingsPage({
    super.key,
    required this.db,
    required this.accountId,
    this.onToggleLocale,
    required this.isDarkMode,
    this.onToggleThemeMode,
    required this.activeThemeStyle,
    this.onThemeStyleChanged,
    this.themeBackgroundImagePath,
    this.onThemeBackgroundImageChanged,
    required this.themeBackgroundMist,
    this.onThemeBackgroundMistChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _kQa3 = 'qa_slot3';
  static const _kQa4 = 'qa_slot4';

  bool _loading = true;
  bool _lowBalanceReminderOn = false;
  bool _suppressAmountListener = false;
  final TextEditingController _lowBalanceCtrl = TextEditingController();

  QuickActionKey _slot3 = QuickActionKey.stats;
  QuickActionKey _slot4 = QuickActionKey.history;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    _lowBalanceCtrl.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _lowBalanceCtrl.removeListener(_onAmountChanged);
    _lowBalanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final minBalance = await Settings.getMinBalance(
      accountId: widget.accountId,
    );
    _lowBalanceReminderOn = minBalance != null;

    _suppressAmountListener = true;
    _lowBalanceCtrl.text = minBalance == null
        ? ''
        : minBalance.toStringAsFixed(2);
    _suppressAmountListener = false;

    final prefs = await SharedPreferences.getInstance();
    final s3 = prefs.getString(_kQa3);
    final s4 = prefs.getString(_kQa4);

    _slot3 = QuickActionKey.values.firstWhere(
      (e) => e.name == s3,
      orElse: () => QuickActionKey.stats,
    );
    _slot4 = QuickActionKey.values.firstWhere(
      (e) => e.name == s4,
      orElse: () => QuickActionKey.history,
    );

    if (_slot3 == _slot4) {
      _slot4 = _slot3 == QuickActionKey.stats
          ? QuickActionKey.history
          : QuickActionKey.stats;
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _saveQuickActions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kQa3, _slot3.name);
    await prefs.setString(_kQa4, _slot4.name);
  }

  void _onAmountChanged() {
    if (_suppressAmountListener || !_lowBalanceReminderOn) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final raw = _lowBalanceCtrl.text.trim();
      if (raw.isEmpty) return;
      final value = double.tryParse(raw.replaceAll(',', ''));
      if (value == null) return;
      await Settings.setMinBalance(value, accountId: widget.accountId);
    });
  }

  Future<void> _turnOnReminder() async {
    final raw = _lowBalanceCtrl.text.trim();
    final parsed =
        double.tryParse(raw.isEmpty ? '0' : raw.replaceAll(',', '')) ?? 0;
    final saved = parsed <= 0 ? 100.0 : parsed;

    _suppressAmountListener = true;
    _lowBalanceCtrl.text = saved.toStringAsFixed(2);
    _suppressAmountListener = false;

    await Settings.setMinBalance(saved, accountId: widget.accountId);
  }

  Future<void> _turnOffReminder() async {
    await Settings.setMinBalance(null, accountId: widget.accountId);
    _suppressAmountListener = true;
    _lowBalanceCtrl.text = '';
    _suppressAmountListener = false;
  }

  Future<void> _openThemeEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ThemeEditorPage(
          isDarkMode: widget.isDarkMode,
          onToggleThemeMode: widget.onToggleThemeMode,
          activeThemeStyle: widget.activeThemeStyle,
          onThemeStyleChanged: widget.onThemeStyleChanged,
          themeBackgroundImagePath: widget.themeBackgroundImagePath,
          onThemeBackgroundImageChanged: widget.onThemeBackgroundImageChanged,
          themeBackgroundMist: widget.themeBackgroundMist,
          onThemeBackgroundMistChanged: widget.onThemeBackgroundMistChanged,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openQuickActionEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _QuickActionEditorPage(
          slot3: _slot3,
          slot4: _slot4,
          onChanged: (s3, s4) async {
            setState(() {
              _slot3 = s3;
              _slot4 = s4;
            });
            await _saveQuickActions();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    return Scaffold(
      appBar: AppBar(title: Text(st(context, 'Settings'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.onToggleLocale != null)
                  Card(
                    child: SwitchListTile(
                      secondary: const Icon(Icons.language),
                      title: Text(st(context, 'Language')),
                      subtitle: Text(isZh ? '简体中文' : 'English'),
                      value: isZh,
                      onChanged: (_) {
                        widget.onToggleLocale?.call();
                        setState(() {});
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: const Icon(
                            Icons.notifications_active_rounded,
                          ),
                          title: Text(st(context, 'Low Balance Reminder')),
                          subtitle: Text(
                            st(
                              context,
                              'Bound to current account and auto-saved',
                            ),
                          ),
                          value: _lowBalanceReminderOn,
                          onChanged: (v) async {
                            setState(() => _lowBalanceReminderOn = v);
                            if (v) {
                              await _turnOnReminder();
                            } else {
                              await _turnOffReminder();
                            }
                          },
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: _lowBalanceReminderOn
                              ? Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    12,
                                  ),
                                  child: TextField(
                                    controller: _lowBalanceCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText: st(context, 'Reminder Amount'),
                                      prefixText: r'$ ',
                                      hintText: st(context, 'e.g. 100'),
                                      helperText: st(
                                        context,
                                        'Saved silently while typing',
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.palette_outlined),
                        title: Text(st(context, 'Theme Editor')),
                        subtitle: Text(
                          '${st(context, 'Current')}: ${themeStyleLabel(context, widget.activeThemeStyle)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _openThemeEditor,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.dashboard_customize_outlined),
                        title: Text(st(context, 'Quick Action Editor')),
                        subtitle: Text(
                          '${st(context, 'Button 3')}: ${qaLabel(context, _slot3)}  ·  ${st(context, 'Button 4')}: ${qaLabel(context, _slot4)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _openQuickActionEditor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(st(context, 'Pet Assistant')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const _PetPage()),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: Text(st(context, 'Import & Export')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _ImportExportPage(db: widget.db),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: Text(st(context, 'Account Security')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const _AccountSecurityPage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SelectionField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String valueText;
  final VoidCallback onTap;

  const _SelectionField({
    required this.label,
    required this.icon,
    required this.valueText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: Row(
          children: [
            Expanded(
              child: Text(
                valueText,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Icon(Icons.expand_more_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

Future<T?> _showSelectionSheet<T>(
  BuildContext context, {
  required String title,
  required List<({T value, String label, IconData icon})> options,
  required T current,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final cs = Theme.of(sheetContext).colorScheme;
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: st(context, 'Close'),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, unused) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final o = options[i];
                  final selected = o.value == current;
                  return ListTile(
                    leading: Icon(
                      o.icon,
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                    ),
                    title: Text(
                      o.label,
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    trailing: selected
                        ? Icon(Icons.check_circle_rounded, color: cs.primary)
                        : null,
                    tileColor: selected
                        ? cs.primaryContainer.withValues(alpha: 0.55)
                        : Colors.transparent,
                    onTap: () => Navigator.of(sheetContext).pop(o.value),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ThemeEditorPage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback? onToggleThemeMode;
  final AppThemeStyle activeThemeStyle;
  final ValueChanged<AppThemeStyle>? onThemeStyleChanged;
  final String? themeBackgroundImagePath;
  final ValueChanged<String?>? onThemeBackgroundImageChanged;
  final double themeBackgroundMist;
  final ValueChanged<double>? onThemeBackgroundMistChanged;

  const _ThemeEditorPage({
    required this.isDarkMode,
    required this.onToggleThemeMode,
    required this.activeThemeStyle,
    required this.onThemeStyleChanged,
    required this.themeBackgroundImagePath,
    required this.onThemeBackgroundImageChanged,
    required this.themeBackgroundMist,
    required this.onThemeBackgroundMistChanged,
  });

  @override
  State<_ThemeEditorPage> createState() => _ThemeEditorPageState();
}

class _ThemeEditorPageState extends State<_ThemeEditorPage> {
  final ImagePicker _picker = ImagePicker();
  late AppThemeStyle _style;

  @override
  void initState() {
    super.initState();
    _style = widget.activeThemeStyle;
  }

  Future<void> _pickStyle() async {
    final picked = await _showSelectionSheet<AppThemeStyle>(
      context,
      title: st(context, 'Select Theme Style'),
      options: AppThemeStyle.values
          .map(
            (e) => (
              value: e,
              label: themeStyleLabel(context, e),
              icon: switch (e) {
                AppThemeStyle.indigo => Icons.auto_awesome_rounded,
                AppThemeStyle.forest => Icons.forest_rounded,
                AppThemeStyle.sunset => Icons.wb_sunny_rounded,
                AppThemeStyle.ocean => Icons.waves_rounded,
              },
            ),
          )
          .toList(growable: false),
      current: _style,
    );
    if (picked == null || picked == _style) return;
    setState(() => _style = picked);
    widget.onThemeStyleChanged?.call(picked);
  }

  Future<void> _pickBackgroundImage() async {
    try {
      final x = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (x == null) return;
      final copiedPath = await _copyImageToAppDir(x.path);
      widget.onThemeBackgroundImageChanged?.call(copiedPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(st(context, 'Background image applied'))),
      );
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(st(context, 'Failed to select image'))),
      );
    }
  }

  Future<String> _copyImageToAppDir(String sourcePath) async {
    final doc = await getApplicationDocumentsDirectory();
    final dir = Directory('${doc.path}${Platform.pathSeparator}theme_bg');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final ext = sourcePath.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final target =
        '${dir.path}${Platform.pathSeparator}bg_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(sourcePath).copy(target);
    return target;
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomImage = (widget.themeBackgroundImagePath ?? '')
        .trim()
        .isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(st(context, 'Theme Editor'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              title: Text(st(context, 'Dark Mode')),
              value: widget.isDarkMode,
              onChanged: (_) {
                widget.onToggleThemeMode?.call();
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _SelectionField(
                label: st(context, 'Theme Style'),
                icon: Icons.palette_rounded,
                valueText: themeStyleLabel(context, _style),
                onTap: _pickStyle,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: Text(st(context, 'Custom Background Image')),
                  subtitle: Text(
                    hasCustomImage
                        ? st(context, 'Configured')
                        : st(context, 'Not configured'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _pickBackgroundImage,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(st(context, 'Choose Image')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: hasCustomImage
                              ? () {
                                  widget.onThemeBackgroundImageChanged?.call(
                                    null,
                                  );
                                  setState(() {});
                                }
                              : null,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: Text(st(context, 'Remove')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: Text(st(context, 'Background White Mist')),
              subtitle: Slider(
                value: widget.themeBackgroundMist.clamp(0.0, 1.0),
                onChanged: (v) {
                  widget.onThemeBackgroundMistChanged?.call(v);
                  setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionEditorPage extends StatefulWidget {
  final QuickActionKey slot3;
  final QuickActionKey slot4;
  final Future<void> Function(QuickActionKey slot3, QuickActionKey slot4)
  onChanged;

  const _QuickActionEditorPage({
    required this.slot3,
    required this.slot4,
    required this.onChanged,
  });

  @override
  State<_QuickActionEditorPage> createState() => _QuickActionEditorPageState();
}

class _QuickActionEditorPageState extends State<_QuickActionEditorPage> {
  late QuickActionKey _slot3;
  late QuickActionKey _slot4;

  @override
  void initState() {
    super.initState();
    _slot3 = widget.slot3;
    _slot4 = widget.slot4;
  }

  Future<void> _pickSlot3() async {
    final options = QuickActionKey.values;
    final picked = await _showSelectionSheet<QuickActionKey>(
      context,
      title: st(context, 'Select Button 3 Action'),
      options: options
          .map((k) => (value: k, label: qaLabel(context, k), icon: qaIcon(k)))
          .toList(growable: false),
      current: _slot3,
    );
    if (picked == null || picked == _slot3) return;
    setState(() {
      _slot3 = picked;
      if (_slot3 == _slot4) _slot4 = options.firstWhere((e) => e != _slot3);
    });
  }

  Future<void> _pickSlot4() async {
    final options = QuickActionKey.values;
    final picked = await _showSelectionSheet<QuickActionKey>(
      context,
      title: st(context, 'Select Button 4 Action'),
      options: options
          .map((k) => (value: k, label: qaLabel(context, k), icon: qaIcon(k)))
          .toList(growable: false),
      current: _slot4,
    );
    if (picked == null || picked == _slot4) return;
    setState(() {
      _slot4 = picked;
      if (_slot4 == _slot3) _slot3 = options.firstWhere((e) => e != _slot4);
    });
  }

  Future<void> _save() async {
    await widget.onChanged(_slot3, _slot4);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(st(context, 'Quick Action Editor'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            st(
              context,
              'Search and Add are fixed on home. Customize slot 3 and slot 4 here.',
            ),
          ),
          const SizedBox(height: 12),
          _SelectionField(
            label: st(context, 'Button 3'),
            icon: qaIcon(_slot3),
            valueText: qaLabel(context, _slot3),
            onTap: _pickSlot3,
          ),
          const SizedBox(height: 12),
          _SelectionField(
            label: st(context, 'Button 4'),
            icon: qaIcon(_slot4),
            valueText: qaLabel(context, _slot4),
            onTap: _pickSlot4,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: Text(st(context, 'Save'))),
        ],
      ),
    );
  }
}

class _PetPage extends StatelessWidget {
  const _PetPage();

  String _frequencyLabel(BuildContext context, PetFrequency value) {
    switch (value) {
      case PetFrequency.low:
        return st(context, 'Low');
      case PetFrequency.normal:
        return st(context, 'Normal');
      case PetFrequency.high:
        return st(context, 'High');
    }
  }

  Future<void> _pickFrequency(BuildContext context, PetConfig cfg) async {
    final picked = await _showSelectionSheet<PetFrequency>(
      context,
      title: st(context, 'Select Talk Frequency'),
      options: [
        (
          value: PetFrequency.low,
          label: st(context, 'Low'),
          icon: Icons.signal_cellular_alt_1_bar_rounded,
        ),
        (
          value: PetFrequency.normal,
          label: st(context, 'Normal'),
          icon: Icons.signal_cellular_alt_2_bar_rounded,
        ),
        (
          value: PetFrequency.high,
          label: st(context, 'High'),
          icon: Icons.signal_cellular_alt_rounded,
        ),
      ],
      current: cfg.frequency,
    );
    if (picked != null) await cfg.setFrequency(picked);
  }

  Future<void> _pickSkin(BuildContext context, PetConfig cfg) async {
    final picked = await _showSelectionSheet<String>(
      context,
      title: st(context, 'Select Appearance'),
      options: PetConfig.skins
          .map((s) => (value: s.id, label: s.name, icon: Icons.pets_rounded))
          .toList(growable: false),
      current: cfg.skinId,
    );
    if (picked != null) await cfg.setSkin(picked);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = PetConfig.I;
    return AnimatedBuilder(
      animation: cfg,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(st(context, 'Pet Assistant'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: SwitchListTile(
                title: Text(st(context, 'Enable Pet')),
                value: cfg.enabled,
                onChanged: cfg.setEnabled,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _SelectionField(
                  label: st(context, 'Talk Frequency'),
                  icon: Icons.record_voice_over_rounded,
                  valueText: _frequencyLabel(context, cfg.frequency),
                  onTap: () => _pickFrequency(context, cfg),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: Text(st(context, 'Pet Size')),
                subtitle: Slider(
                  min: 0,
                  max: 4,
                  divisions: 4,
                  value: cfg.sizeLevel.toDouble(),
                  label: '${cfg.sizeScale.toStringAsFixed(2)}x',
                  onChanged: (v) => cfg.setSizeLevel(v.round()),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _SelectionField(
                  label: st(context, 'Appearance'),
                  icon: Icons.auto_awesome_rounded,
                  valueText: cfg.skin.name,
                  onTap: () => _pickSkin(context, cfg),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportExportPage extends StatelessWidget {
  final AppDatabase db;

  const _ImportExportPage({required this.db});

  @override
  Widget build(BuildContext context) {
    final svc = ImportExportService(db);
    void toast(String msg) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg)));

    return Scaffold(
      appBar: AppBar(title: Text(st(context, 'Import & Export'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton(
            onPressed: () async {
              final f = await svc.exportFullBackupJson();
              await svc.shareFile(f);
              if (!context.mounted) return;
              toast(st(context, 'Backup exported'));
            },
            child: Text(st(context, 'Export Backup (JSON)')),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              final picked = await svc.pickBackupJson();
              if (picked == null) return;
              final r = await svc.importAppend(picked.data);
              if (!context.mounted) return;
              toast(
                st(
                  context,
                  'Imported ${r.insertedTransactions}, skipped ${r.skippedTransactions}',
                ),
              );
            },
            child: Text(st(context, 'Import (Append Only)')),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              final deleted = await svc.clearStoredBillData();
              var cloudDeleted = 0;
              if (Supabase.instance.client.auth.currentUser != null) {
                cloudDeleted = await CloudBillSyncService(
                  db: db,
                  client: Supabase.instance.client,
                ).clearAllCloudBillsForCurrentUser();
              }
              if (!context.mounted) return;
              toast(
                st(context, 'Cleared local $deleted, cloud $cloudDeleted.'),
              );
            },
            child: Text(st(context, 'Clear All Stored Bills')),
          ),
        ],
      ),
    );
  }
}

class _AccountSecurityPage extends StatelessWidget {
  const _AccountSecurityPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(st(context, 'Account Security'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.password_rounded),
                  title: Text(st(context, 'Change Password')),
                  subtitle: Text(
                    st(context, 'Email verification required before update'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const _ChangePasswordPage(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.alternate_email_rounded),
                  title: Text(st(context, 'Change Bound Email')),
                  subtitle: Text(
                    st(context, 'Email verification required before update'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const _ChangeEmailPage()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationPanel extends StatelessWidget {
  final TextEditingController codeController;
  final bool sending;
  final bool verifying;
  final bool verified;
  final VoidCallback onSendCode;
  final VoidCallback onVerifyCode;

  const _VerificationPanel({
    required this.codeController,
    required this.sending,
    required this.verifying,
    required this.verified,
    required this.onSendCode,
    required this.onVerifyCode,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: st(context, 'Email Verification Code'),
                prefixIcon: const Icon(Icons.verified_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: sending || verified ? null : onSendCode,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(
                      sending
                          ? st(context, 'Sending...')
                          : st(context, 'Send Code'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: verifying || verified ? null : onVerifyCode,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: Text(
                      verifying
                          ? st(context, 'Verifying...')
                          : st(context, 'Verify'),
                    ),
                  ),
                ),
              ],
            ),
            if (verified) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.verified_rounded, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    st(context, 'Verification passed'),
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordPage extends StatefulWidget {
  const _ChangePasswordPage();

  @override
  State<_ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<_ChangePasswordPage> {
  final _codeCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  bool _saving = false;
  bool _verified = false;
  String? _error;

  String? get _currentEmail => Supabase.instance.client.auth.currentUser?.email;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _currentEmail;
    if (email == null || email.isEmpty) {
      setState(() => _error = st(context, 'Current email not found.'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(st(context, 'Verification code sent to $email')),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyCode() async {
    final email = _currentEmail;
    final code = _codeCtrl.text.trim();
    if (email == null || email.isEmpty) {
      setState(() => _error = st(context, 'Current email not found.'));
      return;
    }
    if (code.length < 6) {
      setState(
        () => _error = st(context, 'Please enter a valid 6-digit code.'),
      );
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );
      if (!mounted) return;
      setState(() => _verified = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(st(context, 'Email verified'))));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _save() async {
    final pwd = _newPwdCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (!_verified) {
      setState(
        () => _error = st(context, 'Please complete email verification first.'),
      );
      return;
    }
    if (pwd.length < 6) {
      setState(
        () => _error = st(context, 'Password must be at least 6 characters.'),
      );
      return;
    }
    if (pwd != confirm) {
      setState(() => _error = st(context, 'Passwords do not match.'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: pwd),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(st(context, 'Password updated'))));
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _currentEmail ?? '-';
    return Scaffold(
      appBar: AppBar(title: Text(st(context, 'Change Password'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(st(context, 'Current bound email: $email')),
          const SizedBox(height: 12),
          _VerificationPanel(
            codeController: _codeCtrl,
            sending: _sending,
            verifying: _verifying,
            verified: _verified,
            onSendCode: _sendCode,
            onVerifyCode: _verifyCode,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPwdCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: st(context, 'New Password'),
              prefixIcon: const Icon(Icons.lock_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _confirmCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: st(context, 'Confirm Password'),
              prefixIcon: const Icon(Icons.verified_user_rounded),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving
                  ? st(context, 'Saving...')
                  : st(context, 'Update Password'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeEmailPage extends StatefulWidget {
  const _ChangeEmailPage();

  @override
  State<_ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<_ChangeEmailPage> {
  final _codeCtrl = TextEditingController();
  final _newEmailCtrl = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  bool _saving = false;
  bool _verified = false;
  String? _error;

  String? get _currentEmail => Supabase.instance.client.auth.currentUser?.email;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _newEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _currentEmail;
    if (email == null || email.isEmpty) {
      setState(() => _error = st(context, 'Current email not found.'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(st(context, 'Verification code sent to $email')),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyCode() async {
    final email = _currentEmail;
    final code = _codeCtrl.text.trim();
    if (email == null || email.isEmpty) {
      setState(() => _error = st(context, 'Current email not found.'));
      return;
    }
    if (code.length < 6) {
      setState(
        () => _error = st(context, 'Please enter a valid 6-digit code.'),
      );
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );
      if (!mounted) return;
      setState(() => _verified = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(st(context, 'Email verified'))));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _save() async {
    final newEmail = _newEmailCtrl.text.trim();
    if (!_verified) {
      setState(
        () => _error = st(context, 'Please complete email verification first.'),
      );
      return;
    }
    if (!newEmail.contains('@')) {
      setState(() => _error = st(context, 'Please enter a valid email.'));
      return;
    }
    if (newEmail == (_currentEmail ?? '')) {
      setState(
        () => _error = st(context, 'New email cannot be the same as current.'),
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(email: newEmail),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            st(
              context,
              'Bound email update requested. Please check mailbox confirmation.',
            ),
          ),
        ),
      );
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _currentEmail ?? '-';
    return Scaffold(
      appBar: AppBar(title: Text(st(context, 'Change Bound Email'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(st(context, 'Current bound email: $email')),
          const SizedBox(height: 12),
          _VerificationPanel(
            codeController: _codeCtrl,
            sending: _sending,
            verifying: _verifying,
            verified: _verified,
            onSendCode: _sendCode,
            onVerifyCode: _verifyCode,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: st(context, 'New Email'),
              prefixIcon: const Icon(Icons.email_rounded),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving
                  ? st(context, 'Saving...')
                  : st(context, 'Update Bound Email'),
            ),
          ),
        ],
      ),
    );
  }
}
