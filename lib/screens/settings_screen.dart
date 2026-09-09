import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/poultry_provider.dart';
import '../services/cashew_sqlite_importer.dart';
import '../widgets/app_shell.dart';
import 'expense_records_screen.dart';

class SettingsScreen extends StatefulWidget {
  final bool embedded;
  const SettingsScreen({super.key, this.embedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _importing = false;

  Future<void> _importCashewData() async {
    if (_importing) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['sql', 'db', 'sqlite', 'sqlite3'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null || bytes.isEmpty) return;

    setState(() => _importing = true);
    try {
      // Cashew's .sql export is a SQLite database, not a text SQL script.
      // Parse the original database directly; no intermediate JSON is used.
      final records = await parseCashewSqliteBytes(bytes);
      final result = await context.read<PoultryProvider>().importCashewRecords(records);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cashew sync complete: ${result.imported} imported, '
            '${result.updated} updated, ${result.unchanged} unchanged.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cashew SQLite import failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Data Import', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF162A21))),
              const SizedBox(height: 5),
              const Text(
                'Import the original Cashew SQLite export directly. Existing imported transactions are updated to the latest category, account, amount and transaction rules.',
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
                        'The selected .sql file is the original Cashew SQLite database. Category mappings are applied during import, and existing Cashew transactions are updated instead of skipped when the new rules produce different values. Egg sales and poultry Daily Logs are not created from this file.',
                        style: TextStyle(fontSize: 11, height: 1.45, color: Color(0xFF456157)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
                  label: Text(_importing ? 'Importing…' : 'Sync Cashew SQLite Data'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0E9F6E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) return content;
    return PoultryAppShell(
      selectedIndex: 7,
      title: 'Settings',
      subtitle: 'App preferences and data tools',
      child: content,
    );
  }
}
