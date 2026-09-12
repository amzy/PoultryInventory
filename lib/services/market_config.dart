import 'package:shared_preferences/shared_preferences.dart';

class MarketOption {
  final String id;
  final String name;
  final String state;

  const MarketOption({required this.id, required this.name, required this.state});

  String get label => '$name, $state';
}

class MarketConfig {
  MarketConfig._();
  static final instance = MarketConfig._();

  static const _key = 'selected_market_id';

  static const markets = <MarketOption>[
    MarketOption(id: 'ajmer', name: 'Ajmer', state: 'Rajasthan'),
    MarketOption(id: 'jaipur', name: 'Jaipur', state: 'Rajasthan'),
    MarketOption(id: 'jodhpur', name: 'Jodhpur', state: 'Rajasthan'),
    MarketOption(id: 'kota', name: 'Kota', state: 'Rajasthan'),
    MarketOption(id: 'udaipur', name: 'Udaipur', state: 'Rajasthan'),
    MarketOption(id: 'delhi', name: 'Delhi', state: 'Delhi'),
    MarketOption(id: 'ahmedabad', name: 'Ahmedabad', state: 'Gujarat'),
    MarketOption(id: 'mumbai', name: 'Mumbai', state: 'Maharashtra'),
  ];

  String _selectedId = 'ajmer';

  String get selectedId => _selectedId;
  MarketOption get selected => markets.firstWhere(
        (market) => market.id == _selectedId,
        orElse: () => markets.first,
      );

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && markets.any((market) => market.id == saved)) {
      _selectedId = saved;
    }
  }

  Future<void> setMarket(String id) async {
    if (!markets.any((market) => market.id == id)) return;
    _selectedId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, id);
  }
}
