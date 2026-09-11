import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/flock.dart';
import '../providers/poultry_provider.dart';
import '../services/cashew_sqlite_importer.dart';
import '../services/app_sql_export.dart';
import '../services/sql_file_saver.dart';
import '../services/backup_file_saver.dart';
import '../services/farm_config.dart';
import '../services/bv300_metrics_pdf_service.dart';
import '../services/poultry_standard_prompt.dart';
import '../widgets/app_shell.dart';
import 'expense_records_screen.dart';
import 'admin_panel_screen.dart';

class SettingsScreen extends StatefulWidget {
  final bool embedded;
  const SettingsScreen({super.key, this.embedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _importing = false;
  String _importStatus = '';
  final List<TextEditingController> _feedItemControllers = [];
  final List<String> _expenseCategories = [];
  final List<String> _expenseSubcategories = [];
  final _notifTitleEn = TextEditingController(text: 'Daily Farm Update');
  final _notifTitleHi = TextEditingController(text: 'दैनिक फार्म अपडेट');
  final _notifBodyEn = TextEditingController(text: "Please complete today's report for {flockName}.");
  final _notifBodyHi = TextEditingController(text: 'कृपया {flockName} की आज की रिपोर्ट दर्ज करें।');
  bool _notificationsEnabled = true;
  bool _dailyReminderEnabled = true;
  bool _secondReminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _secondReminderTime = const TimeOfDay(hour: 22, minute: 0);
  int _selectedSetting = 0;
  final Set<String> _selectedMetricKeys = <String>{'hdep', 'hhpe', 'fcr_mass', 'water_feed'};
  final List<Map<String, dynamic>> _customStandardProfiles = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadCustomStandardProfiles();
  }

  Future<void> _loadCustomStandardProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('custom_poultry_standard_profiles') ?? <String>[];
      final decoded = <Map<String, dynamic>>[];
      for (final item in raw) {
        final value = jsonDecode(item);
        if (value is Map<String, dynamic>) decoded.add(value);
      }
      if (mounted) setState(() { _customStandardProfiles..clear()..addAll(decoded); });
    } catch (_) {}
  }

  Future<void> _persistCustomStandardProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'custom_poultry_standard_profiles',
      _customStandardProfiles.map((e) => jsonEncode(e)).toList(),
    );
  }

  Future<void> _showStandardPrompt() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Standard Generation Prompt'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: SelectableText(PoultryStandardPrompt.text, style: const TextStyle(fontSize: 11, height: 1.45)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: PoultryStandardPrompt.text));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Standard prompt copied to clipboard.')));
            },
            child: const Text('Copy Prompt'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Share.share(PoultryStandardPrompt.text, subject: 'Poultry Standard JSON Prompt');
            },
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Future<void> _importStandardJson() async {
    final controller = TextEditingController();
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add Standard Metrics from JSON'),
          content: SizedBox(
            width: 720,
            child: TextField(
              controller: controller,
              maxLines: 18,
              decoration: const InputDecoration(
                hintText: '{\n  "breed_metadata": {...},\n  "weekly_performance_matrix": [...]\n}',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Validate & Add')),
          ],
        ),
      );
      if (result == null || result.isEmpty || !mounted) return;
      final decoded = jsonDecode(result);
      if (decoded is! Map<String, dynamic>) throw const FormatException('Root JSON must be an object.');
      final metadata = decoded['breed_metadata'];
      final weekly = decoded['weekly_performance_matrix'];
      if (metadata is! Map<String, dynamic> || weekly is! List || weekly.isEmpty) {
        throw const FormatException('Required breed_metadata and weekly_performance_matrix are missing or invalid.');
      }
      final breedName = (metadata['breed_name'] ?? metadata['strain'] ?? 'Custom strain').toString();
      final weeks = weekly.whereType<Map>().map((e) => (e['week_number'] as num?)?.toInt()).whereType<int>().toList()..sort();
      if (weeks.isEmpty || weeks.first < 1) throw const FormatException('weekly_performance_matrix must contain valid week_number values.');
      if (weeks.toSet().length != weeks.length) throw const FormatException('Each week_number must be unique.');
      final profile = <String, dynamic>{
        'breed_metadata': metadata,
        'weekly_performance_matrix': weekly,
        'environmental_correction_matrix': decoded['environmental_correction_matrix'] ?? <dynamic>[],
        'diagnostic_health_indicators': decoded['diagnostic_health_indicators'] ?? <dynamic>[],
        'imported_at': DateTime.now().toIso8601String(),
      };
      setState(() => _customStandardProfiles.add(profile));
      await _persistCustomStandardProfiles();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$breedName standard added (${weeks.length} weekly records).')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid standard JSON: $e')));
    } finally {
      controller.dispose();
    }
  }

  Future<void> _removeCustomStandard(int index) async {
    final name = (_customStandardProfiles[index]['breed_metadata'] as Map?)?['breed_name']?.toString() ?? 'Custom standard';
    final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Remove standard?'),
      content: Text('Remove "$name" from this device? This does not change historical flock records.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove'))],
    ));
    if (confirmed != true) return;
    setState(() => _customStandardProfiles.removeAt(index));
    await _persistCustomStandardProfiles();
  }

  Future<void> _loadConfig() async {
    try {
      final provider = context.read<PoultryProvider>();
      for (var i = 0; i < 50 && provider.isLoading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final config = provider.farmConfig;
      _applyConfig(config);
    } catch (_) {}
  }

  void _applyConfig(FarmConfig config) {
    for (final c in _feedItemControllers) c.dispose();
    _feedItemControllers.clear();
    final globalFeeds = context.read<PoultryProvider>().feedItems;
    for (final item in globalFeeds) _feedItemControllers.add(TextEditingController(text: item));
    _expenseCategories
      ..clear()
      ..addAll(context.read<PoultryProvider>().expenseCategories);
    _expenseSubcategories
      ..clear()
      ..addAll(context.read<PoultryProvider>().expenseSubcategories);
    _loadNotificationConfig();
  }

  void _addFeedItem() => setState(() => _feedItemControllers.add(TextEditingController()));

  Future<void> _saveFeedCatalog() async {
    if (_importing) return;
    final feedItems = _feedItemControllers.map((c) => c.text.trim()).where((e) => e.isNotEmpty).toSet().toList();
    setState(() => _importing = true);
    try {
      await context.read<PoultryProvider>().saveFeedItems(feedItems);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feed items saved. They are shared across all flocks.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save feed items: $e')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  void dispose() {
    for (final c in _feedItemControllers) c.dispose();
    _notifTitleEn.dispose(); _notifTitleHi.dispose(); _notifBodyEn.dispose(); _notifBodyHi.dispose();
    super.dispose();
  }

  Future<void> _deleteImportedCashewData() async {
    if (_importing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete old Cashew import?'),
        content: const Text(
          'This deletes only transactions created by the Cashew SQLite importer. '
          'Manual expense records and Daily Logs are not deleted. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Imported Data'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _importing = true);
    try {
      final deleted = await context.read<PoultryProvider>().deleteImportedCashewRecords();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $deleted old imported Cashew transaction(s).')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete old Cashew data: $e')),
      );
    } finally {
      if (mounted) setState(() { _importing = false; _importStatus = ''; });
    }
  }

  Future<void> _exportFlockBackup() async {
    if (_importing || !mounted) return;
    final provider = context.read<PoultryProvider>();
    final flocks = provider.flocks;
    if (flocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No flocks are available to export.')));
      return;
    }

    final selected = await showDialog<Flock>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Export Flock Data'),
        content: SizedBox(
          width: 460,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: flocks.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final flock = flocks[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(flock.isActive ? Icons.play_circle_outline : Icons.history_outlined, color: flock.isActive ? const Color(0xFF0E9F6E) : const Color(0xFF7A8B83)),
                title: Text(flock.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${flock.isActive ? 'Running' : 'Ended'} • ${DateFormat('dd MMM yyyy').format(flock.startDate)}${flock.endDate == null ? '' : ' – ${DateFormat('dd MMM yyyy').format(flock.endDate!)}'}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(dialogContext, flock),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel'))],
      ),
    );
    if (selected == null || !mounted) return;

    setState(() { _importing = true; _importStatus = 'Preparing ${selected.name} backup…'; });
    try {
      final backup = await provider.exportFlockBackup(selected.id);
      final json = const JsonEncoder.withIndent('  ').convert(backup);
      final safeName = selected.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_').replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
      final fileName = 'flock_${safeName.isEmpty ? selected.id : safeName}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
      final savedPath = await saveBackupFile(Uint8List.fromList(utf8.encode(json)), fileName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(savedPath == null || savedPath.isEmpty ? 'Backup export cancelled.' : 'Flock backup exported: $savedPath')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Flock backup export failed: $e')));
    } finally {
      if (mounted) setState(() { _importing = false; _importStatus = ''; });
    }
  }

  Future<void> _importFlockBackup() async {
    if (_importing) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null || bytes.isEmpty) return;

    setState(() { _importing = true; _importStatus = 'Reading backup…'; });
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) throw const FormatException('Backup JSON must contain an object.');
      final backup = Map<String, dynamic>.from(decoded);
      final provider = context.read<PoultryProvider>();
      final count = await provider.importFlockBackup(
        backup,
        onProgress: (message) {
          if (mounted) setState(() => _importStatus = message);
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup restored successfully ($count records processed).')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup import failed: $e')));
    } finally {
      if (mounted) setState(() { _importing = false; _importStatus = ''; });
    }
  }

  Future<void> _exportFinancialSql() async {
    if (_importing) return;
    final records = context.read<PoultryProvider>().expenseRecords;
    setState(() => _importing = true);
    try {
      final flock = context.read<PoultryProvider>().activeFlock;
      final sql = AppSqlExport.buildExpenseSql(
        records,
        flockId: flock?.id,
        flockName: flock?.name,
        breedName: flock?.breedName,
      );
      final bytes = Uint8List.fromList(utf8.encode(sql));
      final savedPath = await saveSqlFile(
        bytes,
        'poultry_inventory_financial_export.sql',
      );
      if (!mounted) return;
      if (savedPath == null || savedPath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SQL export cancelled.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SQL export saved: $savedPath')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SQL export failed: $e')),
      );
    } finally {
      if (mounted) setState(() { _importing = false; _importStatus = ''; });
    }
  }

  Future<void> _importCashewData() async {
    if (_importing) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['sql', 'db', 'sqlite', 'sqlite3'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null || bytes.isEmpty) return;

    setState(() { _importing = true; _importStatus = 'Reading import file…'; });
    try {
      // Accept both the original Cashew SQLite database and a SQL file exported by this app.
      final records = await parseCashewSqliteBytes(bytes);
      final result = await context.read<PoultryProvider>().importCashewRecords(
        records,
        onProgress: (message) {
          if (mounted) setState(() => _importStatus = message);
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Data sync complete: ${result.imported} imported, '
            '${result.updated} updated, ${result.unchanged} unchanged.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data import failed: $e')),
      );
    } finally {
      if (mounted) setState(() { _importing = false; _importStatus = ''; });
    }
  }

  Widget _flockPerformanceMetricsPanel() {
    final provider = context.watch<PoultryProvider>();
    final flock = provider.activeFlock;
    final metricList = BV300MetricsPdfService.metrics(
      startingBirds: provider.startingBirdsAtDayZero,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsSectionHeader(
          icon: Icons.insights_outlined,
          title: 'Flock Performance Metrics',
          subtitle: 'Review all available BV300 performance KPIs and export selected metrics as PDF.',
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2EAE5))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Standard Library', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Import a complete strain standard as JSON. The app validates age-based weekly data and keeps each strain separate.', style: TextStyle(fontSize: 10.5, color: Color(0xFF718179), height: 1.35)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(onPressed: _importing ? null : _importStandardJson, icon: const Icon(Icons.data_object), label: const Text('Add Metrics from JSON')),
                OutlinedButton.icon(onPressed: _showStandardPrompt, icon: const Icon(Icons.share_outlined), label: const Text('Share Standard Prompt')),
              ]),
              if (_customStandardProfiles.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...List.generate(_customStandardProfiles.length, (index) {
                  final metadata = _customStandardProfiles[index]['breed_metadata'];
                  final name = metadata is Map ? (metadata['breed_name'] ?? metadata['strain'] ?? 'Custom strain').toString() : 'Custom strain';
                  final weekly = _customStandardProfiles[index]['weekly_performance_matrix'];
                  return ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: const Icon(Icons.verified_outlined, color: Color(0xFF7C3AED)), title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${weekly is List ? weekly.length : 0} weekly benchmark records'), trailing: IconButton(tooltip: 'Remove', onPressed: () => _removeCustomStandard(index), icon: const Icon(Icons.delete_outline, color: Colors.redAccent)));
                }),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 12),
        if (flock == null)
          _settingsInfoCard('No flock selected', 'Select a running or historical flock to view and export its performance metrics.')
        else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FBF8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDCE9E1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.home_work_outlined, color: Color(0xFF0E9F6E)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${flock.name} • ${provider.logs.length} daily log(s)',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A2D24)),
                  ),
                ),
                Text('${_selectedMetricKeys.length} selected', style: const TextStyle(fontSize: 11, color: Color(0xFF60736A))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text('Available metrics', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1A2D24))),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedMetricKeys.addAll(metricList.map((m) => m.key))),
                child: const Text('Select all'),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedMetricKeys.clear()),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...metricList.map((metric) {
            final selected = _selectedMetricKeys.contains(metric.key);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13), side: const BorderSide(color: Color(0xFFE2EAE5))),
              child: CheckboxListTile(
                value: selected,
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _selectedMetricKeys.add(metric.key);
                  } else {
                    _selectedMetricKeys.remove(metric.key);
                  }
                }),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                title: Text(metric.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                subtitle: Text('Unit: ${metric.unit}\nStandard: ${metric.standard}\nAction: ${metric.action}', style: const TextStyle(fontSize: 10, height: 1.35)),
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _selectedMetricKeys.isEmpty || provider.logs.isEmpty || _importing
                  ? null
                  : () => _exportSelectedMetricsPdf(provider, flock),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(_importing ? 'Preparing PDF…' : 'Export Selected Metrics as PDF'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The PDF contains the selected metric, daily actual values, flock age/week, expected standard and action limit. Metrics that require inputs not stored in Daily Log are shown as target-only in the BV300 analytics dashboard and are not exported as actual observations.',
            style: TextStyle(fontSize: 10, color: Color(0xFF718179), height: 1.4),
          ),
        ],
      ],
    );
  }

  Future<void> _exportSelectedMetricsPdf(PoultryProvider provider, Flock flock) async {
    if (_selectedMetricKeys.isEmpty || provider.logs.isEmpty) return;
    setState(() => _importing = true);
    try {
      await BV300MetricsPdfService.export(
        flock: flock,
        logs: provider.logs,
        startingBirds: provider.startingBirdsAtDayZero,
        metricKeys: _selectedMetricKeys.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Performance metrics PDF prepared successfully.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to export metrics PDF: $e')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Widget _settingsSectionHeader({required IconData icon, required String title, required String subtitle}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: const Color(0xFFE7F6EE), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: const Color(0xFF0E9F6E)),
      ),
      const SizedBox(width: 11),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1A2D24))),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF718179), height: 1.35)),
      ])),
    ],
  );

  Widget _settingsInfoCard(String title, String message) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFFF8FAF9), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE1E9E4))),
    child: Row(children: [
      const Icon(Icons.info_outline, color: Color(0xFF0E9F6E)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(message, style: const TextStyle(fontSize: 11, color: Color(0xFF718179))),
      ])),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PoultryProvider>();
    if (!provider.isAdmin) {
      final content = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Settings and administration are managed by the flock administrator.'),
        ),
      );
      if (widget.embedded) return content;
      return PoultryAppShell(
        selectedIndex: 10,
        title: 'Settings',
        subtitle: 'App preferences',
        child: content,
      );
    }

    final panels = <Widget>[
      _flockConfigurationPanel(),
      _flockPerformanceMetricsPanel(),
      _accountsPanel(),
      _feedCatalogPanel(),
      _categoriesPanel(),
      _notificationsPanel(),
      _dataManagementPanel(),
      const AdminPanelScreen(embedded: true, adminOnly: true, showSuppliers: true, showMembers: false),
    ];

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final int selected = _selectedSetting.clamp(0, panels.length - 1).toInt();
        final body = panels[selected];

        if (!wide) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: [
              _settingsHero(),
              const SizedBox(height: 12),
              _settingsCategoryList(compact: true),
              const SizedBox(height: 14),
              body,
            ],
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _settingsHero(),
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 270, child: _settingsCategoryList()),
                    const SizedBox(width: 16),
                    Expanded(child: SingleChildScrollView(child: body)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (widget.embedded) return content;
    return PoultryAppShell(
      selectedIndex: 10,
      title: 'Settings',
      subtitle: 'Farm preferences and administration',
      child: content,
    );
  }

  Widget _settingsHero() => Container(
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8F7EF), Color(0xFFF7FBF8)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD7E9DE)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF0E9F6E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.settings_outlined, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Settings', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF162A21))),
                  SizedBox(height: 3),
                  Text('Manage your farm, app preferences and administration', style: TextStyle(fontSize: 11, color: Color(0xFF60736A))),
                ],
              ),
            ),
            const Icon(Icons.tune_outlined, color: Color(0xFF0E9F6E)),
          ],
        ),
      );

  Widget _settingsCategoryList({bool compact = false}) {
    const items = <_SettingsCategory>[
      _SettingsCategory('Flock Configuration', 'Flocks, members and invitations', Icons.home_work_outlined, Color(0xFF0E9F6E)),
      _SettingsCategory('Flock Performance', 'BV300 KPIs and PDF export', Icons.insights_outlined, Color(0xFF7C3AED)),
      _SettingsCategory('Accounts', 'Saved expense accounts', Icons.account_balance_wallet_outlined, Color(0xFF0891B2)),
      _SettingsCategory('Feed Catalog', 'Shared feed items', Icons.grass_outlined, Color(0xFFF59E0B)),
      _SettingsCategory('Categories', 'Manage categories and subcategories', Icons.category_outlined, Color(0xFFDB2777)),
      _SettingsCategory('Notifications', 'Flock notification settings', Icons.notifications_active_outlined, Color(0xFFEA580C)),
      _SettingsCategory('Data Management', 'Backup, import and export', Icons.storage_outlined, Color(0xFF2563EB)),
      _SettingsCategory('Suppliers', 'Manage supplier contacts and categories', Icons.local_shipping_outlined, Color(0xFF0EA5A4)),
    ];

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) const Padding(padding: EdgeInsets.fromLTRB(6, 0, 6, 8), child: Text('SETTINGS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: Color(0xFF7A8B83)))),
        ...List.generate(items.length, (index) {
          final item = items[index];
          final selected = _selectedSetting == index;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _selectedSetting = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFE7F6EE) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? const Color(0xFFB9DEC8) : const Color(0xFFE2EAE5)),
                    boxShadow: selected ? const [BoxShadow(color: Color(0x100E9F6E), blurRadius: 12, offset: Offset(0, 4))] : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: item.color.withValues(alpha: .10), borderRadius: BorderRadius.circular(11)),
                        child: Icon(item.icon, color: item.color, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1A2D24))),
                            const SizedBox(height: 2),
                            Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: Color(0xFF718179))),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 18, color: selected ? const Color(0xFF0E9F6E) : const Color(0xFF9AA9A2)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );

    return compact ? list : Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E9E4)),
      ),
      child: list,
    );
  }

  Future<void> _selectFlockFromSettings(Flock flock) async {
    if (context.read<PoultryProvider>().activeFlockId == flock.id) return;
    setState(() => _importing = true);
    try {
      await context.read<PoultryProvider>().selectFlock(flock.id);
      if (!mounted) return;
      _applyConfig(context.read<PoultryProvider>().farmConfig);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${flock.name} is now the current flock for this app.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to switch flock: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _showAddFlockDialog() async {
    final provider = context.read<PoultryProvider>();
    if (provider.flocks.where((f) => f.isActive).length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum of 3 running flocks reached. Ended flocks are not counted.')),
      );
      return;
    }

    final nameController = TextEditingController();
    final birdsController = TextEditingController();
    final breedController = TextEditingController();
    DateTime startDate = DateTime.now();
    var selectedAccounts = <String>[];
    final savedAccounts = List<String>.from(provider.savedAccounts);
    if (savedAccounts.isNotEmpty) selectedAccounts = [savedAccounts.first];

    try {
      final created = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Flock'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Flock Name',
                          hintText: 'e.g. Cobb Flock 2',
                          prefixIcon: Icon(Icons.home_work_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: birdsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Starting Bird Count',
                          prefixIcon: Icon(Icons.pets_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: breedController,
                        decoration: const InputDecoration(
                          labelText: 'Breed Name',
                          prefixIcon: Icon(Icons.category_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        readOnly: true,
                        controller: TextEditingController(
                          text: DateFormat('dd MMM yyyy').format(startDate),
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Flock Start Date',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                          border: OutlineInputBorder(),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => startDate = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Accounts', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF243A30))),
                      ),
                      const SizedBox(height: 6),
                      if (savedAccounts.isEmpty)
                        const Align(alignment: Alignment.centerLeft, child: Text('Add an account in Settings → Accounts before creating a flock.', style: TextStyle(fontSize: 10.5, color: Color(0xFFB45309))))
                      else
                        ...savedAccounts.map((account) => CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(account, style: const TextStyle(fontSize: 12)),
                          value: selectedAccounts.contains(account),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selectedAccounts = [...selectedAccounts, account];
                              } else if (selectedAccounts.length > 1) {
                                selectedAccounts = selectedAccounts.where((e) => e != account).toList();
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                        )),
                      const SizedBox(height: 4),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'New flocks start in Running state. Select at least one saved account. You can end a flock later without deleting its records.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF60736A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final birds = int.tryParse(birdsController.text.trim());
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Enter a flock name.')),
                      );
                      return;
                    }
                    if (birds == null || birds < 0) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Enter a valid starting bird count.')),
                      );
                      return;
                    }
                    if (selectedAccounts.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Select at least one account.')),
                      );
                      return;
                    }

                    try {
                      await provider.createFlock(
                        name: name,
                        startDate: startDate,
                        startingBirds: birds,
                        breedName: breedController.text.trim(),
                        accounts: List<String>.from(selectedAccounts),
                        feedItems: provider.feedItems,
                      );
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('Unable to add flock: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Flock'),
                ),
              ],
            );
          },
        ),
      );
      if (created == true && mounted) {
        _applyConfig(provider.farmConfig);
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flock added and made current for this app.')),
        );
      }
    } finally {
      nameController.dispose();
      birdsController.dispose();
      breedController.dispose();
    }
  }

  Future<void> _endFlock(Flock flock) async {
    if (!flock.isActive) return;
    final endDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: flock.startDate,
      lastDate: DateTime.now(),
    );
    if (endDate == null || !mounted) return;

    setState(() => _importing = true);
    try {
      await context.read<PoultryProvider>().endFlock(flock.id, endDate);
      if (!mounted) return;
      _applyConfig(context.read<PoultryProvider>().farmConfig);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${flock.name} marked as ended.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to end flock: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _showFlockAccountsDialog(Flock flock) async {
    final provider = context.read<PoultryProvider>();
    final savedAccounts = List<String>.from(provider.savedAccounts);
    final available = <String>{...savedAccounts, ...flock.accounts}.toList();
    var selected = flock.accounts.where(available.contains).toSet();
    if (selected.isEmpty && available.isNotEmpty) selected = {available.first};

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Accounts • ${flock.name}'),
          content: SizedBox(
            width: 420,
            child: available.isEmpty
                ? const Text('No saved accounts. Add an account in Settings → Accounts first.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select one or more saved accounts for this flock.', style: TextStyle(fontSize: 11, color: Color(0xFF60736A))),
                      const SizedBox(height: 8),
                      ...available.map((account) => CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(account, style: const TextStyle(fontSize: 12)),
                            value: selected.contains(account),
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  selected.add(account);
                                } else if (selected.length > 1) {
                                  selected.remove(account);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          )),
                    ],
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () async {
                      try {
                        await provider.updateFlockAccounts(flock.id, selected.toList());
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Flock accounts updated.')));
                      } catch (e) {
                        if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Unable to update accounts: $e')));
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _flockListSection() {
    return Consumer<PoultryProvider>(
      builder: (context, provider, _) {
        final runningFlocks = provider.flocks.where((f) => f.isActive).toList();
        final runningCount = runningFlocks.length;
        final currentId = provider.activeFlockId;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF7FBF8), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDCE9E1))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Running Flocks', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF243A30))),
                SizedBox(height: 3),
                Text('Select the flock currently used by this app. Ended flocks remain in history but are not shown here.', style: TextStyle(fontSize: 10, height: 1.35, color: Color(0xFF60736A))),
              ])),
              const SizedBox(width: 10),
              OutlinedButton.icon(onPressed: runningCount >= 3 || _importing ? null : _showAddFlockDialog, icon: const Icon(Icons.add, size: 17), label: Text(runningCount >= 3 ? '3 / 3 running' : 'Add Flock')),
            ]),
            const SizedBox(height: 10),
            if (runningFlocks.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No running flocks available.', style: TextStyle(fontSize: 11, color: Color(0xFF718179))))
            else
              ...runningFlocks.map((flock) {
                final isCurrent = flock.id == currentId;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(color: isCurrent ? const Color(0xFFEAF7F0) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isCurrent ? const Color(0xFFB8DEC8) : const Color(0xFFE1E9E4))),
                  child: Row(children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFE5F7ED), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.play_circle_outline, color: Color(0xFF0E9F6E), size: 20)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Flexible(child: Text(flock.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1A2D24)))), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFDDF4E7), borderRadius: BorderRadius.circular(20)), child: const Text('Running', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF087A4F))))]),
                      const SizedBox(height: 3),
                      Text('${flock.breedName.isEmpty ? 'Breed not set' : flock.breedName}  •  ${flock.startingBirds} birds  •  ${flock.accounts.isEmpty ? 'No accounts' : flock.accounts.join(', ')}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: Color(0xFF718179))),
                    ])),
                    const SizedBox(width: 6),
                    if (provider.isAdmin) IconButton(tooltip: 'Select accounts', onPressed: _importing ? null : () => _showFlockAccountsDialog(flock), icon: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF0891B2), size: 20)),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Current', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF60736A))),
                      Switch.adaptive(value: isCurrent, onChanged: isCurrent || _importing ? null : (_) => _selectFlockFromSettings(flock), activeTrackColor: const Color(0xFF0E9F6E)),
                    ]),
                    const SizedBox(width: 2),
                    if (provider.isAdmin) IconButton(tooltip: 'End flock', onPressed: _importing ? null : () => _endFlock(flock), icon: const Icon(Icons.stop_circle_outlined, color: Color(0xFFB45309), size: 21)),
                  ]),
                );
              }),
          ]),
        );
      },
    );
  }

  Widget _flockConfigurationPanel() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _panelTitle('Flock Configuration', 'Manage running flocks, members and invitations', Icons.home_work_outlined),
              const SizedBox(height: 14),
              _flockListSection(),
            ]),
          ),
          const SizedBox(height: 12),
          const AdminPanelScreen(embedded: true, adminOnly: true, showSuppliers: false, showMembers: true),
        ],
      );

  Future<void> _showSavedAccountDialog({String? existing}) async {
    final controller = TextEditingController(text: existing ?? '');
    final provider = context.read<PoultryProvider>();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'Add Account' : 'Update Account'),
        content: TextField(controller: controller, autofocus: true, maxLength: 80, decoration: const InputDecoration(labelText: 'Account Name', hintText: 'e.g. Farm Cash', prefixIcon: Icon(Icons.account_balance_wallet_outlined), border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () { final value = controller.text.trim(); if (value.isEmpty) { ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Enter an account name.'))); return; } Navigator.pop(dialogContext, value); }, child: Text(existing == null ? 'Add' : 'Update')),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    final accounts = List<String>.from(provider.savedAccounts);
    if (existing != null) {
      final index = accounts.indexOf(existing);
      if (index >= 0) accounts[index] = result;
    } else {
      if (accounts.any((e) => e.toLowerCase() == result.toLowerCase())) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That account already exists.'))); return; }
      accounts.add(result);
    }
    try {
      await provider.saveSavedAccounts(accounts);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(existing == null ? 'Account added.' : 'Account updated.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save account: $e')));
    }
  }

  Future<void> _deleteSavedAccount(String account) async {
    final provider = context.read<PoultryProvider>();
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Delete account?'), content: Text('Remove "$account" from your saved account list? Existing flock records and historical transactions will not be deleted.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete'))])) ?? false;
    if (!confirmed || !mounted) return;
    final accounts = provider.savedAccounts.where((e) => e != account).toList();
    if (accounts.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least one saved account must remain.'))); return; }
    try {
      await provider.saveSavedAccounts(accounts);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deleted from the saved list.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to delete account: $e')));
    }
  }

  Widget _accountsPanel() => Consumer<PoultryProvider>(
        builder: (context, provider, _) => AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: _panelTitle('Accounts', 'Saved accounts available to assign to one or more flocks', Icons.account_balance_wallet_outlined)),
              OutlinedButton.icon(onPressed: _importing ? null : () => _showSavedAccountDialog(), icon: const Icon(Icons.add, size: 17), label: const Text('Add Account')),
            ]),
            const SizedBox(height: 14),
            if (provider.savedAccounts.isEmpty)
              const Text('No saved accounts.', style: TextStyle(fontSize: 11, color: Color(0xFF718179)))
            else
              ...provider.savedAccounts.map((account) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE1E9E4))),
                    child: Row(children: [
                      const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF0891B2), size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(account, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF243A30)))),
                      IconButton(tooltip: 'Edit account', onPressed: _importing ? null : () => _showSavedAccountDialog(existing: account), icon: const Icon(Icons.edit_outlined, size: 19)),
                      IconButton(tooltip: 'Delete account', onPressed: _importing ? null : () => _deleteSavedAccount(account), icon: const Icon(Icons.delete_outline, color: Colors.red, size: 19)),
                    ]),
                  )),
            const SizedBox(height: 6),
            const Text('Deleting a saved account only removes it from the reusable account catalog. Existing flock assignments and historical transactions are preserved.', style: TextStyle(fontSize: 10.5, height: 1.4, color: Color(0xFF60736A))),
          ]),
        ),
      );

  Widget _feedCatalogPanel() => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _panelTitle('Feed Catalog', 'Shared feed items available across all flocks', Icons.grass_outlined),
            const SizedBox(height: 14),
            ..._feedItemControllers.asMap().entries.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Expanded(child: TextField(controller: entry.value, decoration: InputDecoration(labelText: 'Feed Item ${entry.key + 1}', border: const OutlineInputBorder()))), const SizedBox(width: 8), IconButton(onPressed: () => setState(() { final c = _feedItemControllers.removeAt(entry.key); c.dispose(); }), icon: const Icon(Icons.remove_circle_outline, color: Colors.red))]))),
            OutlinedButton.icon(onPressed: _addFeedItem, icon: const Icon(Icons.add), label: const Text('Add Feed Item')),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 44, child: FilledButton.icon(onPressed: _importing ? null : _saveFeedCatalog, icon: const Icon(Icons.save_outlined), label: const Text('Save Feed Items'))),
          ],
        ),
      );

  Future<void> _loadNotificationConfig() async {
    final p = context.read<PoultryProvider>();
    if (p.activeFlockId.isEmpty) return;
    try {
      final settings = await p.fetchNotificationSettings();
      final template = await p.fetchNotificationTemplate('daily_report_reminder');
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = settings?['enabled'] != false;
        _dailyReminderEnabled = settings?['dailyReportReminder'] != false;
        _secondReminderEnabled = settings?['secondReminderEnabled'] == true;
        _reminderTime = TimeOfDay(hour: (settings?['reminderHour'] as num?)?.toInt() ?? 20, minute: (settings?['reminderMinute'] as num?)?.toInt() ?? 0);
        _secondReminderTime = TimeOfDay(hour: (settings?['secondReminderHour'] as num?)?.toInt() ?? 22, minute: (settings?['secondReminderMinute'] as num?)?.toInt() ?? 0);
        _notifTitleEn.text = template?['titleEn']?.toString() ?? _notifTitleEn.text;
        _notifTitleHi.text = template?['titleHi']?.toString() ?? _notifTitleHi.text;
        _notifBodyEn.text = template?['bodyEn']?.toString() ?? _notifBodyEn.text;
        _notifBodyHi.text = template?['bodyHi']?.toString() ?? _notifBodyHi.text;
      });
    } catch (_) {}
  }

  Future<void> _saveNotifications() async {
    final p = context.read<PoultryProvider>();
    try {
      await p.saveNotificationSettings({'enabled': _notificationsEnabled, 'dailyReportReminder': _dailyReminderEnabled, 'secondReminderEnabled': _secondReminderEnabled, 'reminderHour': _reminderTime.hour, 'reminderMinute': _reminderTime.minute, 'secondReminderHour': _secondReminderTime.hour, 'secondReminderMinute': _secondReminderTime.minute, 'timezone': 'Asia/Kolkata'});
      await p.saveNotificationTemplate('daily_report_reminder', {'titleEn': _notifTitleEn.text.trim(), 'titleHi': _notifTitleHi.text.trim(), 'bodyEn': _notifBodyEn.text.trim(), 'bodyHi': _notifBodyHi.text.trim(), 'enabled': _dailyReminderEnabled, 'reminderHour': _reminderTime.hour, 'reminderMinute': _reminderTime.minute, 'secondReminderHour': _secondReminderTime.hour, 'secondReminderMinute': _secondReminderTime.minute, 'secondReminderEnabled': _secondReminderEnabled});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification settings saved.')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save notifications: $e'))); }
  }

  Future<void> _pickNotificationTime(bool first) async {
    final t = await showTimePicker(context: context, initialTime: first ? _reminderTime : _secondReminderTime);
    if (t != null && mounted) setState(() { if (first) { _reminderTime = t; } else { _secondReminderTime = t; } });
  }

  Future<void> _sendNotificationAnnouncement() async {
    try {
      await context.read<PoultryProvider>().sendFlockNotification(titleEn: _notifTitleEn.text.trim(), titleHi: _notifTitleHi.text.trim(), bodyEn: _notifBodyEn.text.trim(), bodyHi: _notifBodyHi.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification queued for flock members.')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to send notification: $e'))); }
  }

  Widget _notificationsPanel() => AppCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _panelTitle('Notifications', 'Configure reminders and flock announcements', Icons.notifications_active_outlined),
      const SizedBox(height: 12),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Enable flock notifications'), value: _notificationsEnabled, onChanged: (v) => setState(() => _notificationsEnabled = v)),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Daily report reminder'), value: _dailyReminderEnabled, onChanged: (v) => setState(() => _dailyReminderEnabled = v)),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _notificationTimeTile('Reminder time', _reminderTime, () => _pickNotificationTime(true)),
        _notificationTimeTile('Second reminder', _secondReminderTime, () => _pickNotificationTime(false)),
      ]),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Enable second reminder'), value: _secondReminderEnabled, onChanged: (v) => setState(() => _secondReminderEnabled = v)),
      const Divider(height: 28),
      const Text('Daily Report Reminder — configurable localization', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      TextField(controller: _notifTitleEn, decoration: const InputDecoration(labelText: 'Title — English', border: OutlineInputBorder())), const SizedBox(height: 8),
      TextField(controller: _notifTitleHi, decoration: const InputDecoration(labelText: 'Title — Hindi', border: OutlineInputBorder())), const SizedBox(height: 8),
      TextField(controller: _notifBodyEn, maxLines: 2, decoration: const InputDecoration(labelText: 'Message — English', helperText: 'Variables: {memberName}, {flockName}, {breedName}, {date}', border: OutlineInputBorder())), const SizedBox(height: 8),
      TextField(controller: _notifBodyHi, maxLines: 2, decoration: const InputDecoration(labelText: 'Message — Hindi', helperText: 'Variables: {memberName}, {flockName}, {breedName}, {date}', border: OutlineInputBorder())), const SizedBox(height: 10),
      Row(children: [Expanded(child: FilledButton.icon(onPressed: _saveNotifications, icon: const Icon(Icons.save_outlined), label: const Text('Save Notification Settings'))), const SizedBox(width: 8), OutlinedButton.icon(onPressed: _sendNotificationAnnouncement, icon: const Icon(Icons.send_outlined), label: const Text('Send Test / Announcement'))]),
    ]),
  );

  Widget _notificationTimeTile(String label, TimeOfDay time, VoidCallback onTap) => SizedBox(width: 220, child: ListTile(shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xFFDCE7E0)), borderRadius: BorderRadius.circular(8)), title: Text(label), subtitle: Text(time.format(context)), trailing: const Icon(Icons.schedule), onTap: onTap));

  Future<void> _editCategory({required bool subcategory, String? existing}) async {
    final controller = TextEditingController(text: existing ?? '');
    final value = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: Text(existing == null ? 'Add ${subcategory ? 'Subcategory' : 'Category'}' : 'Edit ${subcategory ? 'Subcategory' : 'Category'}'), content: TextField(controller: controller, autofocus: true, maxLength: 120, decoration: InputDecoration(labelText: subcategory ? 'Subcategory Name' : 'Category Name', border: const OutlineInputBorder())), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () { final v = controller.text.trim(); if (v.isNotEmpty) Navigator.pop(ctx, v); }, child: Text(existing == null ? 'Add' : 'Update'))]));
    controller.dispose();
    if (value == null || !mounted) return;
    final target = subcategory ? _expenseSubcategories : _expenseCategories;
    final duplicate = target.any((e) => e.toLowerCase() == value.toLowerCase() && e != existing);
    if (duplicate) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That name already exists.'))); return; }
    final updated = List<String>.from(target);
    if (existing == null) { updated.add(value); } else { final i = updated.indexOf(existing); if (i >= 0) updated[i] = value; }
    try {
      if (subcategory) { await context.read<PoultryProvider>().saveExpenseSubcategories(updated); } else { await context.read<PoultryProvider>().saveExpenseCategories(updated); }
      setState(() { target..clear()..addAll(updated); });
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save: $e'))); }
  }

  Future<void> _deleteCategory({required bool subcategory, required String value}) async {
    final target = subcategory ? _expenseSubcategories : _expenseCategories;
    if (target.length <= 1) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least one item must remain.'))); return; }
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text('Delete ${subcategory ? 'subcategory' : 'category'}?'), content: Text('Remove "$value" from the saved catalog? Existing transaction history is not deleted.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))])) ?? false;
    if (!ok || !mounted) return;
    final updated = target.where((e) => e != value).toList();
    try {
      if (subcategory) { await context.read<PoultryProvider>().saveExpenseSubcategories(updated); } else { await context.read<PoultryProvider>().saveExpenseCategories(updated); }
      setState(() { target..clear()..addAll(updated); });
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to delete: $e'))); }
  }

  Widget _categoryManagementList({required bool subcategory}) {
    final items = subcategory ? _expenseSubcategories : _expenseCategories;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(subcategory ? 'Subcategories' : 'Categories', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))), OutlinedButton.icon(onPressed: () => _editCategory(subcategory: subcategory), icon: const Icon(Icons.add, size: 18), label: Text('Add ${subcategory ? 'Subcategory' : 'Category'}'))]),
      const SizedBox(height: 8),
      if (items.isEmpty) const Text('No items configured.'),
      ...items.map((item) => Container(margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2EAE5)), borderRadius: BorderRadius.circular(10)), child: Row(children: [Expanded(child: Text(item, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))), IconButton(tooltip: 'Edit', onPressed: () => _editCategory(subcategory: subcategory, existing: item), icon: const Icon(Icons.edit_outlined, size: 18)), IconButton(tooltip: 'Delete', onPressed: () => _deleteCategory(subcategory: subcategory, value: item), icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red))]))),
    ]);
  }

  Widget _categoriesPanel() => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _panelTitle('Categories', 'Manage expense categories and subcategories', Icons.category_outlined),
    const SizedBox(height: 14),
    _categoryManagementList(subcategory: false),
    const Divider(height: 32),
    _categoryManagementList(subcategory: true),
  ]));

  Widget _dataManagementPanel() => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _panelTitle('Data Management', 'Backup, import and manage financial data', Icons.storage_outlined),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF5FAF7), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDCE7E0))),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline, color: Color(0xFF0E9F6E)), SizedBox(width: 10), Expanded(child: Text('Export a complete backup for any running or ended flock, restore a previous backup, or import external financial data. Flock backups include the flock and its daily logs, financial records, members, invitations and notification configuration.', style: TextStyle(fontSize: 11, height: 1.45, color: Color(0xFF456157))))]),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, height: 42, child: OutlinedButton.icon(onPressed: _importing ? null : _exportFlockBackup, icon: const Icon(Icons.folder_zip_outlined), label: const Text('Export Flock Data'))),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, height: 42, child: OutlinedButton.icon(onPressed: _importing ? null : _importFlockBackup, icon: const Icon(Icons.restore_outlined), label: const Text('Import Data from Backup'))),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, height: 42, child: OutlinedButton.icon(onPressed: _importing ? null : _exportFinancialSql, icon: const Icon(Icons.download_outlined), label: const Text('Export Financial Data as SQL'))),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, height: 42, child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseRecordsScreen())), icon: const Icon(Icons.account_tree_outlined), label: const Text('Manage & Group Expenses'))),
            const SizedBox(height: 8),
            SizedBox(height: 48, width: double.infinity, child: FilledButton.icon(onPressed: _importing ? null : _importCashewData, icon: _importing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.upload_file_outlined), label: Text(_importing ? (_importStatus.isEmpty ? 'Importing…' : _importStatus) : 'Import External Data'))),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, height: 42, child: OutlinedButton.icon(onPressed: _importing ? null : _deleteImportedCashewData, icon: const Icon(Icons.delete_outline, color: Colors.red), label: const Text('Delete Old Imported Cashew Data'), style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Color(0xFFE5BDBD))))),
          ],
        ),
      );

  Widget _panelTitle(String title, String subtitle, IconData icon) => Row(
        children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFE6F5ED), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: const Color(0xFF0E9F6E), size: 21)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF162A21))), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF75867D)))])),
        ],
      );
}

class _SettingsCategory {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _SettingsCategory(this.title, this.subtitle, this.icon, this.color);
}
