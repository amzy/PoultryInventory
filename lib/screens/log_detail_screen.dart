import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/poultry_log.dart';
import 'log_form_screen.dart';

class LogDetailScreen extends StatelessWidget {
  final PoultryLog log;

  const LogDetailScreen({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Daily Log Details'),
        backgroundColor: const Color(0xFF10243D),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Edit Daily Log',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => LogFormScreen(existingLog: log)));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          _header(),
          const SizedBox(height: 14),
          _section('Flock', Icons.pets, [
            _value('Date', DateFormat('dd MMM yyyy').format(log.date)),
            _value('Mortality', '${log.mortality}'),
            if (log.createdByName != null) _value('Added by', log.createdByName!),
            if (log.updatedByName != null) _value('Last updated by', log.updatedByName!),
          ]),
          const SizedBox(height: 12),
          _section('Production', Icons.egg_alt, [
            _value('Trays', _number(log.trays)),
            _value('Total Eggs', '${log.totalEggs}'),
            _value('Avg Tray Weight', '${_number(log.avgTrayWeight)} g'),
          ]),
          const SizedBox(height: 12),
          _section('Consumption', Icons.local_dining_outlined, [
            _value('Feed Consumed', '${_number(log.feedConsumed)} kg'),
            _value('Stone/Grit', '${_number(log.stoneGritConsumed)} kg'),
            _value('Water Intake', '${_number(log.waterIntake)} L'),
            _value('FCR / Egg Mass', log.fcrByEggMass.toStringAsFixed(2)),
          ]),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withOpacity(.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.calendar_month, color: Color(0xFF67E8F9)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, dd MMMM yyyy').format(log.date),
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${log.totalEggs} eggs  •  ${log.mortality} mortality',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: const Color(0xFF67E8F9)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const Divider(color: Colors.white12, height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _value(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12))),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}