import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class MarketPrice {
  final String marketId;
  final String marketName;
  final double? todayPrice;
  final double? yesterdayPrice;
  final double? change;
  final double? percent;
  final double? pricePerTray;
  final double? pricePer100;
  final String dateKey;
  final String source;
  final String sourceUrl;
  final String status;
  final DateTime? updatedAt;

  const MarketPrice({
    required this.marketId,
    required this.marketName,
    required this.todayPrice,
    required this.yesterdayPrice,
    required this.change,
    required this.percent,
    required this.pricePerTray,
    required this.pricePer100,
    required this.dateKey,
    required this.source,
    required this.sourceUrl,
    required this.status,
    required this.updatedAt,
  });

  bool get isAvailable => status == 'live' && todayPrice != null;
  bool get isUp => (change ?? 0) > 0;
  bool get isDown => (change ?? 0) < 0;
  bool get isUnchanged => (change ?? 0) == 0;

  factory MarketPrice.fromFirestore(String marketId, Map<String, dynamic> data) {
    double? number(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value');
    DateTime? date(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return value is DateTime ? value : null;
    }
    return MarketPrice(
      marketId: marketId,
      marketName: data['marketName']?.toString() ?? marketId,
      todayPrice: number(data['todayPrice']),
      yesterdayPrice: number(data['yesterdayPrice']),
      change: number(data['change']),
      percent: number(data['percent']),
      pricePerTray: number(data['pricePerTray']),
      pricePer100: number(data['pricePer100']),
      dateKey: data['dateKey']?.toString() ?? '',
      source: data['source']?.toString() ?? '',
      sourceUrl: data['sourceUrl']?.toString() ?? '',
      status: data['status']?.toString() ?? 'unavailable',
      updatedAt: date(data['updatedAt']),
    );
  }
}

class MarketPriceService {
  MarketPriceService._();
  static final instance = MarketPriceService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
  final Set<String> _initialRefreshRequested = <String>{};

  Stream<MarketPrice?> watchMarket(String marketId) {
    return _db.collection('market_prices').doc(marketId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return MarketPrice.fromFirestore(snap.id, snap.data() ?? const {});
    });
  }

  /// Triggers the server-side market collector once when the selected market
  /// has no Firestore document yet. The scheduled function remains the normal
  /// daily refresh; this only bootstraps first-time/empty installations.
  Future<void> refreshIfMissing(String marketId) async {
    if (_initialRefreshRequested.contains(marketId)) return;

    final existing = await fetchMarket(marketId);
    if (existing != null) {
      _initialRefreshRequested.add(marketId);
      return;
    }

    _initialRefreshRequested.add(marketId);
    try {
      final callable = _functions.httpsCallable('refreshEggMarketPrices');
      await callable.call(<String, dynamic>{'marketId': marketId});
    } catch (_) {
      // Keep the normal scheduled collector as the fallback. Do not surface a
      // startup error when the callable is temporarily unavailable.
    }
  }

  Future<MarketPrice?> fetchMarket(String marketId) async {
    final snap = await _db.collection('market_prices').doc(marketId).get();
    if (!snap.exists) return null;
    return MarketPrice.fromFirestore(snap.id, snap.data() ?? const {});
  }
}
