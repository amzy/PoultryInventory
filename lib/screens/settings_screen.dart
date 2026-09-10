import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/flock.dart';
import '../providers/poultry_provider.dart';
import '../services/cashew_sqlite_importer.dart';
import '../services/app_sql_export.dart';
import '../services/sql_file_saver.dart';
import '../services/farm_config.dart';
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
  final _startDateController = TextEditingController();
  final _startingBirdsController = TextEditingController();
  final _breedController = TextEditingController();
  final List<TextEditingController> _accountControllers = [];
  final List<TextEditingController> _feedItemControllers = [];
  bool _configLoaded = false;
  int _selectedSetting = 0;
  DateTime _startDate = FarmConfig.defaultFlockStartDate;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final provider = context.read<PoultryProvider>();
      for (var i = 0; i < 50 && provider.isLoading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final config = provider.farmConfig;
      _applyConfig(config);
      if (mounted) setState(() => _configLoaded = true);
    } catch (_) {}
  }

  void _applyConfig(FarmConfig config) {
    _startDate = config.flockStartDate;
    _startDateController.text = DateFormat('dd MMM yyyy').format(_startDate);
    _startingBirdsController.text = config.startingBirds.toString();
    _breedController.text = config.breedName;
    for (final c in _accountControllers) c.dispose();
    for (final c in _feedItemControllers) c.dispose();
    _accountControllers.clear();
    _feedItemControllers.clear();
    for (final account in config.accounts) _accountControllers.add(TextEditingController(text: account));
    final globalFeeds = context.read<PoultryProvider>().feedItems;
    for (final item in globalFeeds) _feedItemControllers.add(TextEditingController(text: item));
  }

  void _addAccount() => setState(() => _accountControllers.add(TextEditingController()));
  void _addFeedItem() => setState(() => _feedItemControllers.add(TextEditingController()));

  Future<void> _saveFlockConfig() async {
    final birds = int.tryParse(_startingBirdsController.text.trim());
    if (birds == null || birds < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid starting bird count.')));
      return;
    }
    final accounts = _accountControllers.map((c) => c.text.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one account.')));
      return;
    }
    final config = FarmConfig(flockStartDate: _startDate, startingBirds: birds, breedName: _breedController.text.trim(), accounts: accounts, feedItems: context.read<PoultryProvider>().feedItems);
    try {
      await context.read<PoultryProvider>().saveFarmConfig(config);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Flock configuration saved.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save flock configuration: $e')));
    }
  }

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
    _startDateController.dispose(); _startingBirdsController.dispose(); _breedController.dispose();
    for (final c in _accountControllers) c.dispose();
    for (final c in _feedItemControllers) c.dispose();
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
      _feedCatalogPanel(),
      _dataManagementPanel(),
      const AdminPanelScreen(embedded: true, adminOnly: true),
    ];

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final selected = _selectedSetting.clamp(0, panels.length - 1);
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
      _SettingsCategory('Flock Configuration', 'Farm and flock details', Icons.home_work_outlined, Color(0xFF0E9F6E)),
      _SettingsCategory('Feed Catalog', 'Shared feed items', Icons.grass_outlined, Color(0xFFF59E0B)),
      _SettingsCategory('Data Management', 'Backup, import and export', Icons.storage_outlined, Color(0xFF2563EB)),
      _SettingsCategory('Administration', 'Members, suppliers and notifications', Icons.admin_panel_settings_outlined, Color(0xFF7C3AED)),
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
                      const SizedBox(height: 10),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'New flocks start in Running state. You can end a flock later without deleting its records.',
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

                    try {
                      await provider.createFlock(
                        name: name,
                        startDate: startDate,
                        startingBirds: birds,
                        breedName: breedController.text.trim(),
                        accounts: List<String>.from(FarmConfig.defaultAccounts),
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
      await context.read<PoultryProvider>().updateActiveFlock(
        name: flock.name,
        startDate: flock.startDate,
        startingBirds: flock.startingBirds,
        breedName: flock.breedName,
        accounts: flock.accounts,
        endDate: endDate,
      );
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

  Widget _flockListSection() {
    return Consumer<PoultryProvider>(
      builder: (context, provider, _) {
        final flocks = provider.flocks;
        final runningCount = flocks.where((f) => f.isActive).length;
        final currentId = provider.activeFlockId;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FBF8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDCE9E1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Flocks', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF243A30))),
                        SizedBox(height: 3),
                        Text('The current flock is app-specific. Switching here changes the flock used by this app on this device/browser only.', style: TextStyle(fontSize: 10, height: 1.35, color: Color(0xFF60736A))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: runningCount >= 3 || _importing ? null : _showAddFlockDialog,
                    icon: const Icon(Icons.add, size: 17),
                    label: Text(runningCount >= 3 ? '3 / 3 running' : 'Add Flock'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (flocks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No flocks available.', style: TextStyle(fontSize: 11, color: Color(0xFF718179))),
                )
              else
                ...flocks.map((flock) {
                  final isCurrent = flock.id == currentId;
                  final running = flock.isActive;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: isCurrent ? const Color(0xFFEAF7F0) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isCurrent ? const Color(0xFFB8DEC8) : const Color(0xFFE1E9E4)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: running ? const Color(0xFFE5F7ED) : const Color(0xFFF0F1F1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(running ? Icons.play_circle_outline : Icons.check_circle_outline, color: running ? const Color(0xFF0E9F6E) : const Color(0xFF7B8580), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(child: Text(flock.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1A2D24)))),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: running ? const Color(0xFFDDF4E7) : const Color(0xFFEDEFEF),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(running ? 'Running' : 'Ended', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: running ? const Color(0xFF087A4F) : const Color(0xFF68736E))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${flock.breedName.isEmpty ? 'Breed not set' : flock.breedName}  •  ${flock.startingBirds} birds  •  Started ${DateFormat('dd MMM yyyy').format(flock.startDate)}${flock.endDate == null ? '' : '  •  Ended ${DateFormat('dd MMM yyyy').format(flock.endDate!)}'}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 9.5, color: Color(0xFF718179)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Current', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF60736A))),
                            Switch.adaptive(
                              value: isCurrent,
                              onChanged: isCurrent || _importing ? null : (_) => _selectFlockFromSettings(flock),
                              activeTrackColor: const Color(0xFF0E9F6E),
                            ),
                          ],
                        ),
                        if (running) ...[
                          const SizedBox(width: 2),
                          IconButton(
                            tooltip: 'End flock',
                            onPressed: _importing ? null : () => _endFlock(flock),
                            icon: const Icon(Icons.stop_circle_outlined, color: Color(0xFFB45309), size: 21),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _flockConfigurationPanel() => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _panelTitle('Flock Configuration', 'Manage up to 3 running flocks; ended flocks are kept for history', Icons.home_work_outlined),
            const SizedBox(height: 14),
            _flockListSection(),
            const SizedBox(height: 18),
            LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth >= 700;
              final fields = <Widget>[
                TextField(controller: _startDateController, readOnly: true, decoration: const InputDecoration(labelText: 'Flock Start Date', prefixIcon: Icon(Icons.calendar_today_outlined), border: OutlineInputBorder()), onTap: () async { final picked = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2000), lastDate: DateTime.now()); if (picked != null) setState(() { _startDate = picked; _startDateController.text = DateFormat('dd MMM yyyy').format(picked); }); }),
                TextField(controller: _startingBirdsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Starting Bird Count', prefixIcon: Icon(Icons.pets_outlined), border: OutlineInputBorder())),
                TextField(controller: _breedController, decoration: const InputDecoration(labelText: 'Breed Name', prefixIcon: Icon(Icons.category_outlined), border: OutlineInputBorder())),
              ];
              return Wrap(spacing: 10, runSpacing: 10, children: fields.map((w) => SizedBox(width: wide ? (c.maxWidth - 20) / 3 : c.maxWidth, child: w)).toList());
            }),
            const SizedBox(height: 16),
            const Text('Accounts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF243A30))),
            const SizedBox(height: 8),
            ..._accountControllers.asMap().entries.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Expanded(child: TextField(controller: entry.value, decoration: InputDecoration(labelText: 'Account ${entry.key + 1}', border: const OutlineInputBorder()))), const SizedBox(width: 8), IconButton(onPressed: () => setState(() { final c = _accountControllers.removeAt(entry.key); c.dispose(); }), icon: const Icon(Icons.remove_circle_outline, color: Colors.red))]))),
            OutlinedButton.icon(onPressed: _addAccount, icon: const Icon(Icons.add), label: const Text('Add Account')),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, height: 44, child: FilledButton.icon(onPressed: _importing ? null : _saveFlockConfig, icon: const Icon(Icons.save_outlined), label: const Text('Save Flock Configuration'))),
          ],
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

  Widget _dataManagementPanel() => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _panelTitle('Data Management', 'Backup, import and manage financial data', Icons.storage_outlined),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF5FAF7), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDCE7E0))),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline, color: Color(0xFF0E9F6E)), SizedBox(width: 10), Expanded(child: Text('Export financial records as SQL or import Cashew SQLite/SQL data. Imported records use deterministic IDs and never create Daily Logs.', style: TextStyle(fontSize: 11, height: 1.45, color: Color(0xFF456157))))]),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, height: 42, child: OutlinedButton.icon(onPressed: _importing ? null : _exportFinancialSql, icon: const Icon(Icons.download_outlined), label: const Text('Export Financial Data as SQL'))),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, height: 42, child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseRecordsScreen())), icon: const Icon(Icons.account_tree_outlined), label: const Text('Manage & Group Expenses'))),
            const SizedBox(height: 8),
            SizedBox(height: 48, width: double.infinity, child: FilledButton.icon(onPressed: _importing ? null : _importCashewData, icon: _importing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.upload_file_outlined), label: Text(_importing ? (_importStatus.isEmpty ? 'Importing…' : _importStatus) : 'Sync Cashew SQLite Data'))),
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
