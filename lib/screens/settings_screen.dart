import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/poultry_provider.dart';
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
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() => _importing = true);
    try {
      final bytes = result.files.single.bytes!;
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic> || decoded['records'] is! List) {
        throw const FormatException('Invalid Cashew import file.');
      }

      final records = List<Map<String, dynamic>>.from(
        (decoded['records'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );

      final imported = await context.read<PoultryProvider>().importCashewRecords(records);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$imported Cashew records imported. Existing imported records were skipped.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cashew import failed: $e')),
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
                'Import old financial records exported from the Cashew app.',
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
                        'Cashew expenses keep their original Cashew category. They are imported under Main Category = Cashew so you can manually change the Main Category or Category later. Egg sales and poultry daily logs are not created from this file.',
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
                  label: Text(_importing ? 'Importing…' : 'Import Cashew Data'),
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
