import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/poultry_provider.dart';
import '../services/cashew_sqlite_importer.dart';
import '../services/app_sql_export.dart';
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
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _exportFinancialSql() async {
    if (_importing) return;
    final records = context.read<PoultryProvider>().expenseRecords;
    setState(() => _importing = true);
    try {
      final sql = AppSqlExport.buildExpenseSql(records);
      final bytes = Uint8List.fromList(utf8.encode(sql));
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Poultry Inventory financial data',
        fileName: 'poultry_inventory_financial_export.sql',
        type: FileType.custom,
        allowedExtensions: ['sql'],
        bytes: bytes,
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
      if (mounted) setState(() => _importing = false);
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

    setState(() => _importing = true);
    try {
      // Accept both the original Cashew SQLite database and a SQL file exported by this app.
      final records = await parseCashewSqliteBytes(bytes);
      final result = await context.read<PoultryProvider>().importCashewRecords(records);
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
                  label: Text(_importing ? 'Importing…' : 'Sync Cashew SQLite Data'),
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
