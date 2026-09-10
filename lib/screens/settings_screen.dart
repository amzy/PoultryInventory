import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
      final content = const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Settings and administration are managed by the flock administrator.')));
      if (widget.embedded) return content;
      return PoultryAppShell(selectedIndex: 9, title: 'Settings', subtitle: 'App preferences', child: content);
    }

    final content = ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Flock Configuration', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF162A21))),
              const SizedBox(height: 5),
              const Text('Configure the flock and the accounts available in financial pickers. Feed Items are managed independently and are shared across flocks.', style: TextStyle(fontSize: 11, color: Color(0xFF75867D))),
              const SizedBox(height: 16),
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
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 44, child: FilledButton.icon(onPressed: _importing ? null : _saveFlockConfig, icon: const Icon(Icons.save_outlined), label: const Text('Save Flock Configuration'))),

            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Feed Items', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF162A21))),
              const SizedBox(height: 5),
              const Text('Feed items are independent of flock configuration and use the same catalog for every flock.', style: TextStyle(fontSize: 11, color: Color(0xFF75867D))),
              const SizedBox(height: 12),
              ..._feedItemControllers.asMap().entries.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Expanded(child: TextField(controller: entry.value, decoration: InputDecoration(labelText: 'Feed Item ${entry.key + 1}', border: const OutlineInputBorder()))), const SizedBox(width: 8), IconButton(onPressed: () => setState(() { final c = _feedItemControllers.removeAt(entry.key); c.dispose(); }), icon: const Icon(Icons.remove_circle_outline, color: Colors.red))]))),
              OutlinedButton.icon(onPressed: _addFeedItem, icon: const Icon(Icons.add), label: const Text('Add Feed Item')),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, height: 44, child: FilledButton.icon(onPressed: _importing ? null : _saveFeedCatalog, icon: const Icon(Icons.save_outlined), label: const Text('Save Feed Items'))),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Data Backup & Sync', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF162A21))),
              const SizedBox(height: 5),
              const Text(
                'Export the current financial records as portable SQL, or import either a Cashew SQLite export or SQL previously exported by this app. Sync uses deterministic IDs so the same source can be imported again safely.',
                style: TextStyle(fontSize: 11, color: Color(0xFF75867D)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5FAF7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDCE7E0)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF0E9F6E)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'The import is validated against the four current financial main categories. Electricity is mapped to Layer Bird → Electricity, and source transactions without a specific subcategory use Other Expenses. Accounts are preserved. Daily Logs are never created by this import.',
                        style: TextStyle(fontSize: 11, height: 1.45, color: Color(0xFF456157)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: _importing ? null : _exportFinancialSql,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Export Financial Data as SQL'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0E9F6E),
                    side: const BorderSide(color: Color(0xFFBFD8CA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseRecordsScreen())),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('Manage & Group Expenses'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _importing ? null : _importCashewData,
                  icon: _importing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload_file_outlined),
                  label: Text(_importing ? (_importStatus.isEmpty ? 'Importing…' : _importStatus) : 'Sync Cashew SQLite Data'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0E9F6E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: _importing ? null : _deleteImportedCashewData,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Delete Old Imported Cashew Data'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Color(0xFFE5BDBD)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (provider.isAdmin) ...[
          const SizedBox(height: 14),
          const AdminPanelScreen(embedded: true, adminOnly: true),
        ],
      ],
    );

    if (widget.embedded) return content;
    return PoultryAppShell(
      selectedIndex: 9,
      title: 'Settings',
      subtitle: 'App preferences and data tools',
      child: content,
    );
  }
}
