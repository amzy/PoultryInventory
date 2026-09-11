import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import '../models/poultry_log.dart';
import '../models/expense_sales_log.dart';
import '../models/flock.dart';
import '../models/supplier.dart';
import '../services/firebase_service.dart';
import '../services/farm_config.dart';
import '../services/expense_category_config.dart';
import '../services/notification_service.dart';
import '../services/bv300_analytics_service.dart';

class PoultryProvider with ChangeNotifier {
  final FirebaseService _firebase = FirebaseService();
  List<PoultryLog> _logs = [];
  List<ExpenseSalesLog> _expenseRecords = [];
  List<String> _feedItems = List<String>.from(FarmConfig.defaultFeedItems);
  List<String> _expenseCategories = List<String>.from(ExpenseCategoryConfig.defaultMainCategories);
  List<String> _expenseSubcategories = List<String>.from(ExpenseCategoryConfig.defaultSubcategories);
  List<Supplier> _suppliers = [];
  List<String> _savedAccounts = List<String>.from(FarmConfig.defaultAccounts);
  bool _expenseRecordsLoaded = false;
  bool _expenseRecordsLoading = false;
  Future<void>? _expenseLoadFuture;
  String? _expenseRecordsError;

  bool _isLoading = false;
  FarmConfig _farmConfig = FarmConfig.defaults;
  List<Flock> _flocks = [];
  Flock? _activeFlock;
  bool _isAdmin = false;
  Map<String, bool> _featureAccess = {};
  String? _errorMessage;
  StreamSubscription? _authSub;
  List<PoultryLog> get logs => List.unmodifiable(_logs);
  List<ExpenseSalesLog> get expenseRecords => List.unmodifiable(_expenseRecords);
  List<String> get feedItems => List.unmodifiable(_feedItems);
  List<String> get expenseCategories => List.unmodifiable(_expenseCategories);
  List<String> get expenseSubcategories => List.unmodifiable(_expenseSubcategories);
  List<Supplier> get suppliers => List.unmodifiable(_suppliers);
  List<String> get savedAccounts => List.unmodifiable(_savedAccounts);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _firebase.isSignedIn;
  FarmConfig get farmConfig => _farmConfig;
  List<Flock> get flocks => List.unmodifiable(_flocks);
  Flock? get activeFlock => _activeFlock;
  bool get isAdmin => _isAdmin;
  bool hasFeature(String feature) => _isAdmin || (_featureAccess[feature] ?? false);
  Map<String, bool> get featureAccess => Map.unmodifiable(_featureAccess);
  String get activeFlockId => _activeFlock?.id ?? '';
  bool get hasFlock => _activeFlock != null;
  PoultryProvider() { _authSub = _firebase.authChanges.listen((_) { if (_firebase.isSignedIn) { _startup(); } else { _resetLocal(); } }); _startup(); }
  Future<void> _startup() async {
    _isLoading = true;
    notifyListeners();
    try {
      if (_firebase.isSignedIn) {
        await _reload();
        // Token registration should never delay the first dashboard render.
        // It can complete in the background after the farm data is available.
        NotificationService.instance.registerToken().catchError((_) {});
      }
    } catch (e) {
      _errorMessage = 'Unable to load Firebase data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  Future<void> _reload() async {
    _isAdmin = await _firebase.ensureUserProfile();
    _flocks = await _firebase.fetchFlocks();
    if (_flocks.isEmpty) {
      _logs = [];
      _expenseRecords = [];
      _activeFlock = null;
      _farmConfig = FarmConfig(flockStartDate: DateTime.now(), startingBirds: 0, breedName: '', accounts: const [], feedItems: const []);
      _featureAccess = {};
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('active_flock_${_firebase.currentUser?.uid ?? ''}');
    final currentId = savedId ?? _activeFlock?.id;
    final matches = _flocks.where((f) => f.id == currentId && f.isActive).toList();
    final running = _flocks.where((f) => f.isActive).toList();
    final selected = matches.isNotEmpty ? matches.first : (running.isNotEmpty ? running.first : _flocks.first);
    _activeFlock = selected;
    _featureAccess = await _firebase.fetchActiveFlockFeatureAccess(selected.id);
    await prefs.setString('active_flock_${_firebase.currentUser?.uid ?? ''}', selected.id);
    _firebase.setActiveFlock(selected.id);
    // Critical dashboard data is loaded first. Financial records, catalogs and
    // suppliers are intentionally deferred so the first dashboard frame can
    // render flock context and daily-log metrics without waiting on several
    // additional Firestore reads.
    final logs = await _firebase.fetchLogs();
    _logs = List<PoultryLog>.from(logs)..sort((a,b)=>b.date.compareTo(a.date));
    _expenseRecords = [];
    _expenseRecordsLoaded = false;
    _expenseRecordsLoading = false;
    _expenseLoadFuture = null;
    _expenseRecordsError = null;

    _farmConfig = FarmConfig(
      flockStartDate: selected.startDate,
      startingBirds: selected.startingBirds,
      breedName: selected.breedName,
      accounts: selected.accounts,
      feedItems: _feedItems,
    );
    ExpenseCategoryConfig.setAccounts(_farmConfig.accounts);

    // Secondary settings/catalog data is useful to forms and settings but is
    // not required for the first dashboard paint.
    _loadSecondaryDataInBackground();
  }

  Future<void> _loadSecondaryDataInBackground() async {
    try {
      final results = await Future.wait<dynamic>([
        _firebase.fetchGlobalFeedItems().catchError((_) => List<String>.from(FarmConfig.defaultFeedItems)),
        _firebase.fetchGlobalExpenseCategories().catchError((_) => List<String>.from(ExpenseCategoryConfig.defaultMainCategories)),
        _firebase.fetchGlobalExpenseSubcategories().catchError((_) => List<String>.from(ExpenseCategoryConfig.defaultSubcategories)),
        _firebase.fetchSuppliers().catchError((_) => <Supplier>[]),
        _firebase.fetchSavedAccounts().catchError((_) => List<String>.from(FarmConfig.defaultAccounts)),
      ]);
      if (!_firebase.isSignedIn) return;
      _feedItems = List<String>.from(results[0] as List<String>);
      _expenseCategories = List<String>.from(results[1] as List<String>);
      _expenseSubcategories = List<String>.from(results[2] as List<String>);
      _suppliers = List<Supplier>.from(results[3] as List<Supplier>);
      _savedAccounts = List<String>.from(results[4] as List<String>);
      ExpenseCategoryConfig.setMainCategories(_expenseCategories);
      ExpenseCategoryConfig.setSubcategories(_expenseSubcategories);
      if (_activeFlock != null) {
        _farmConfig = FarmConfig(
          flockStartDate: _activeFlock!.startDate,
          startingBirds: _activeFlock!.startingBirds,
          breedName: _activeFlock!.breedName,
          accounts: _activeFlock!.accounts,
          feedItems: _feedItems,
        );
        ExpenseCategoryConfig.setAccounts(_farmConfig.accounts);
      }
      notifyListeners();
    } catch (_) {
      // Secondary dashboard/settings data is best-effort. The critical daily
      // logs already rendered and should not be blocked by these reads.
    }
  }

  Future<void> loadExpenseRecords({bool force = false}) async {
    if (!isAdmin && !hasFeature('expenses')) {
      _expenseRecords = [];
      _expenseRecordsLoaded = true;
      _expenseRecordsLoading = false;
      _expenseRecordsError = null;
      return;
    }
    if (_expenseRecordsLoaded && !force) return;
    if (_expenseLoadFuture != null && !force) return _expenseLoadFuture!;

    _expenseRecordsLoading = true;
    _expenseRecordsError = null;
    notifyListeners();

    final future = _loadExpenseRecordsInternal();
    _expenseLoadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_expenseLoadFuture, future)) _expenseLoadFuture = null;
    }
  }

  Future<void> _loadExpenseRecordsInternal() async {
    try {
      final records = await _firebase.fetchExpenseRecords().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Financial records took too long to load.'),
      );
      _expenseRecords = List<ExpenseSalesLog>.from(records)..sort((a, b) => b.date.compareTo(a.date));
      _expenseRecordsLoaded = true;
      _expenseRecordsError = null;
    } catch (error) {
      _expenseRecords = [];
      _expenseRecordsLoaded = true;
      _expenseRecordsError = error.toString();
    } finally {
      _expenseRecordsLoading = false;
      notifyListeners();
    }
  }

  bool get expenseRecordsLoaded => _expenseRecordsLoaded;
  bool get expenseRecordsLoading => _expenseRecordsLoading;
  String? get expenseRecordsError => _expenseRecordsError;

  Future<void> selectFlock(String flockId) async {
    final matches = _flocks.where((f) => f.id == flockId).toList();
    final flock = matches.isNotEmpty ? matches.first : await _firebase.fetchFlock(flockId);
    if (flock == null) throw StateError('Flock not found.');
    _activeFlock = flock;
    _firebase.setActiveFlock(flock.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_flock_${_firebase.currentUser?.uid ?? ''}', flock.id);
    await _reload();
  }

  Future<String> createFlock({required String name, required DateTime startDate, required int startingBirds, required String breedName, required List<String> accounts, required List<String> feedItems}) async {
    final id = await _firebase.createFlock(name: name, startDate: startDate, startingBirds: startingBirds, breedName: breedName, accounts: accounts, feedItems: feedItems);
    await _reload();
    await selectFlock(id);
    return id;
  }

  Future<void> endFlock(String flockId, DateTime endDate) async {
    await _firebase.endFlock(flockId, endDate);
    await _reload();
  }

  Future<void> updateActiveFlock({required String name, required DateTime startDate, required int startingBirds, required String breedName, required List<String> accounts, List<String>? feedItems, DateTime? endDate}) async {
    final flock = _activeFlock;
    if (flock == null) throw StateError('Select a flock first.');
    final updated = Flock(id: flock.id, name: name, startDate: startDate, endDate: endDate, startingBirds: startingBirds, breedName: breedName, accounts: accounts, feedItems: flock.feedItems, createdByUid: flock.createdByUid);
    await _firebase.updateFlock(updated);
    await _reload();
  }

  Future<Map<String, dynamic>> fetchUserProfile() => _firebase.fetchUserProfile();

  Future<void> updateUserProfile({
    required String displayName,
    required String email,
    required String mobileNumber,
    int? age,
    String? avatarBase64,
  }) async {
    await _firebase.updateUserProfile(
      displayName: displayName,
      email: email,
      mobileNumber: mobileNumber,
      age: age,
      avatarBase64: avatarBase64,
    );
    notifyListeners();
  }

  Future<List<FlockMembership>> fetchFlockMembers(String flockId) => _firebase.fetchMembers(flockId);
  Stream<List<FlockMembership>> watchFlockMembers(String flockId) => _firebase.watchMemberStatuses(flockId);
  Future<int> syncInvitedMembers(String flockId) => _firebase.syncInvitedMembers(flockId);
  Future<void> updateMemberFeatureAccess(String uid, Map<String, bool> access, {String? flockId}) async { await _firebase.updateMemberFeatureAccess(flockId ?? activeFlockId, uid, access); }
  Future<void> updateInvitationFeatureAccess(String email, Map<String, bool> access, {String? flockId}) async { await _firebase.updateInvitationFeatureAccess(flockId ?? activeFlockId, email, access); }
  Future<void> inviteFlockMember(String email, {String? flockId}) async { final id = flockId ?? activeFlockId; if (id.isEmpty) throw StateError('Select a flock first.'); await _firebase.inviteMember(flockId: id, email: email); }
  Future<void> resendFlockInvitation(String invitationId, {String? flockId}) async { final id = flockId ?? activeFlockId; if (id.isEmpty) throw StateError('Select a flock first.'); await _firebase.resendInvitation(id, invitationId); }
  Future<List<Map<String, dynamic>>> pendingInvitations() => _firebase.pendingInvitationsForEmail(_firebase.currentUser?.email ?? '');
  Future<void> acceptFlockInvitation(String flockId, String invitationId) async { await _firebase.acceptInvitation(flockId, invitationId); await _reload(); notifyListeners(); }
  Future<void> declineFlockInvitation(String flockId, String invitationId) async { await _firebase.declineInvitation(flockId, invitationId); notifyListeners(); }
  Future<Map<String, dynamic>?> fetchNotificationSettings() => _firebase.fetchNotificationSettings(activeFlockId);
  Future<void> saveNotificationSettings(Map<String, dynamic> data) => _firebase.saveNotificationSettings(activeFlockId, data);
  Future<Map<String, dynamic>?> fetchNotificationTemplate(String id) => _firebase.fetchNotificationTemplate(activeFlockId, id);
  Future<void> saveNotificationTemplate(String id, Map<String, dynamic> data) => _firebase.saveNotificationTemplate(activeFlockId, id, data);
  Future<void> sendFlockNotification({required String titleEn, required String titleHi, required String bodyEn, required String bodyHi, String? memberUid}) => _firebase.sendFlockNotification(flockId: activeFlockId, titleEn:titleEn, titleHi:titleHi, bodyEn:bodyEn, bodyHi:bodyHi, memberUid:memberUid);
  Future<void> updateMemberDetails(String uid, {String? mobileNumber, String? notificationLanguage, String? flockId}) => _firebase.updateMemberDetails(flockId ?? activeFlockId, uid, mobileNumber:mobileNumber, notificationLanguage:notificationLanguage);
  Future<void> updateMemberRole(String uid, String role, {String? flockId}) => _firebase.updateMemberRole(flockId ?? activeFlockId, uid, role);
  Future<void> removeFlockMember(String uid, {String? flockId}) async { final id = flockId ?? activeFlockId; if (id.isEmpty) throw StateError('Select a flock first.'); await _firebase.removeMember(id, uid); }
  Future<void> setFlockMemberStatus(String uid, String status, {String? flockId}) async { final id = flockId ?? activeFlockId; if (id.isEmpty) throw StateError('Select a flock first.'); await _firebase.setMemberStatus(id, uid, status); }
  Future<Map<String, dynamic>> exportFlockBackup(String flockId) => _firebase.exportFlockBackup(flockId);
  Future<int> importFlockBackup(Map<String, dynamic> backup, {void Function(String message)? onProgress}) async { final count = await _firebase.importFlockBackup(backup, onProgress: onProgress); await _reload(); notifyListeners(); return count; }

  void _resetLocal() {
    _logs = []; _expenseRecords = []; _expenseRecordsLoaded = false; _expenseRecordsLoading = false; _expenseLoadFuture = null; _flocks = []; _activeFlock = null; _feedItems = List<String>.from(FarmConfig.defaultFeedItems); _expenseCategories = List<String>.from(ExpenseCategoryConfig.defaultMainCategories); _expenseSubcategories = List<String>.from(ExpenseCategoryConfig.defaultSubcategories); _suppliers = []; _savedAccounts = List<String>.from(FarmConfig.defaultAccounts); ExpenseCategoryConfig.setMainCategories(_expenseCategories); ExpenseCategoryConfig.setSubcategories(_expenseSubcategories); _farmConfig = FarmConfig.defaults; _isAdmin = false; _featureAccess = {}; _errorMessage = null; notifyListeners();
  }

  Future<void> fetchLogs() async { if(!_firebase.isSignedIn)return; final reloadExpenses=_expenseRecordsLoaded; _isLoading=true;notifyListeners();try{await _reload();if(reloadExpenses) await loadExpenseRecords(force:true);_errorMessage=null;}catch(e){_errorMessage='Error loading Firebase data: $e';}finally{_isLoading=false;notifyListeners();} }
  Future<void> addLog(PoultryLog log) async {
    try {
      await _firebase.addDailyLog(log);
      await fetchLogs();
    } on FirebaseException catch (e) {
      _errorMessage = e.code == 'permission-denied'
          ? 'Daily log was not saved: Firestore permissions rejected the write. Deploy the latest firestore.rules to the poultryinventory project.'
          : 'Daily log was not saved: ${e.message ?? e.code}';
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = 'Daily log was not saved: $e';
      notifyListeners();
      rethrow;
    }
  }
  Future<void> updateLog(PoultryLog log) async { try{await _firebase.updateDailyLog(log);await fetchLogs();}catch(e){_errorMessage='Daily log was not updated: $e';notifyListeners();rethrow;} }
  Future<void> addExpenseRecord(ExpenseSalesLog record) async { try{final wasLoaded=_expenseRecordsLoaded;await _firebase.addExpenseRecord(record);await fetchLogs();if(wasLoaded) await loadExpenseRecords(force:true);}catch(e){_errorMessage='Expense/sale was not saved: $e';notifyListeners();rethrow;} }
  Future<void> updateExpenseRecord(ExpenseSalesLog record) async { try{final wasLoaded=_expenseRecordsLoaded;await _firebase.updateExpenseRecord(record);await fetchLogs();if(wasLoaded) await loadExpenseRecords(force:true);}catch(e){_errorMessage='Expense/sale was not updated: $e';notifyListeners();rethrow;} }
  Future<int> deleteImportedCashewRecords() async {
    try {
      final deleted = await _firebase.deleteImportedCashewRecords();
      await fetchLogs();
      _errorMessage = null;
      return deleted;
    } catch (e) {
      _errorMessage = 'Unable to delete imported Cashew records: $e';
      notifyListeners();
      rethrow;
    }
  }
  Future<CashewImportResult> importCashewRecords(List<Map<String, dynamic>> records, {void Function(String message)? onProgress}) async {
    try {
      final imported = await _firebase.importCashewRecords(records, onProgress: onProgress);
      await fetchLogs();
      _errorMessage = null;
      return imported;
    } catch (e) {
      _errorMessage = 'Cashew import failed: $e';
      notifyListeners();
      rethrow;
    }
  }
  Future<void> saveFeedItems(List<String> items) async {
    await _firebase.saveGlobalFeedItems(items);
    _feedItems = items.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (_feedItems.isEmpty) _feedItems = List<String>.from(FarmConfig.defaultFeedItems);
    _farmConfig = FarmConfig(flockStartDate: _farmConfig.flockStartDate, startingBirds: _farmConfig.startingBirds, breedName: _farmConfig.breedName, accounts: _farmConfig.accounts, feedItems: _feedItems);
    notifyListeners();
  }

  Future<void> saveExpenseCategories(List<String> items) async {
    await _firebase.saveGlobalExpenseCategories(items);
    _expenseCategories = items.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (_expenseCategories.isEmpty) _expenseCategories = List<String>.from(ExpenseCategoryConfig.defaultMainCategories);
    ExpenseCategoryConfig.setMainCategories(_expenseCategories);
    notifyListeners();
  }

  Future<void> saveExpenseSubcategories(List<String> items) async {
    await _firebase.saveGlobalExpenseSubcategories(items);
    _expenseSubcategories = items.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (_expenseSubcategories.isEmpty) _expenseSubcategories = List<String>.from(ExpenseCategoryConfig.defaultSubcategories);
    ExpenseCategoryConfig.setSubcategories(_expenseSubcategories);
    notifyListeners();
  }

  Future<void> reloadSuppliers() async {
    _suppliers = await _firebase.fetchSuppliers();
    notifyListeners();
  }

  Future<void> addSupplier(Supplier supplier) async {
    final id = await _firebase.addSupplier(supplier);
    _suppliers = [..._suppliers, supplier.copyWith(id: id)]..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    notifyListeners();
  }

  Future<void> updateSupplier(Supplier supplier) async {
    await _firebase.updateSupplier(supplier);
    _suppliers = _suppliers.map((x) => x.id == supplier.id ? supplier : x).toList()
      ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    notifyListeners();
  }

  Future<void> deleteSupplier(String supplierId) async {
    await _firebase.deleteSupplier(supplierId);
    _suppliers = _suppliers.where((x) => x.id != supplierId).toList();
    notifyListeners();
  }

  Future<List<ExpenseSalesLog>> fetchFlockExpenseRecords({
    required String flockId,
    String? mainCategory,
    String? subcategory,
    String? supplierId,
    DateTime? startDate,
    DateTime? endDate,
  }) => _firebase.fetchFlockExpenseRecords(
    flockId: flockId,
    mainCategory: mainCategory,
    subcategory: subcategory,
    supplierId: supplierId,
    startDate: startDate,
    endDate: endDate,
  );

  Future<void> signOut() async { await _firebase.signOut(); _resetLocal(); }
  @override void dispose(){_authSub?.cancel();super.dispose();}
  int get totalMortality=>_logs.fold(0,(s,e)=>s+e.mortality);
  int get startingBirdsAtDayZero => _farmConfig.startingBirds;
  int get totalBirds => (startingBirdsAtDayZero - totalMortality).clamp(0, startingBirdsAtDayZero).toInt();
  double get mortalityPercentage => startingBirdsAtDayZero == 0 ? 0 : totalMortality / startingBirdsAtDayZero * 100;
  double layingPercentageFor(PoultryLog log) {
    final cumulative = _logs.where((x) => !x.date.isAfter(log.date)).fold<int>(0, (sum, x) => sum + x.mortality);
    final int alive = (startingBirdsAtDayZero - cumulative).clamp(0, startingBirdsAtDayZero).toInt();
    return alive == 0 ? 0 : (log.totalEggs / alive) * 100;
  }
  double get latestLayingPercentage => _logs.isEmpty ? 0 : layingPercentageFor(_logs.first);
  double get averageLayingPercentage => _logs.isEmpty ? 0 : _logs.map(layingPercentageFor).reduce((a,b)=>a+b)/_logs.length;
  BV300AnalyticsSnapshot get bv300Analytics {
    final ageDays = _activeFlock == null ? 0 : FarmConfig.flockAgeOnDate(DateTime.now(), startDate: _activeFlock!.startDate);
    final latest = _logs.isEmpty ? null : _logs.first;
    final cumulativeEggs = latest == null
        ? null
        : _logs.where((x) => !x.date.isAfter(latest.date)).fold<int>(0, (sum, x) => sum + x.totalEggs).toDouble();
    return BV300AnalyticsService.evaluate(
      ageDays: ageDays,
      latestLog: latest,
      livability: startingBirdsAtDayZero == 0 ? 0 : totalBirds / startingBirdsAtDayZero * 100,
      layingPercentage: latest == null ? 0 : layingPercentageFor(latest),
      cumulativeEggs: cumulativeEggs,
      originalBirdsHoused: startingBirdsAtDayZero,
    );
  }
  int aliveBirdsOn(DateTime date) {
    final mortality = _logs.where((x) => !x.date.isAfter(date)).fold<int>(0, (sum, x) => sum + x.mortality);
    return (startingBirdsAtDayZero - mortality).clamp(0, startingBirdsAtDayZero).toInt();
  }
  double mortalityPercentageOn(DateTime date) => startingBirdsAtDayZero == 0 ? 0 : (startingBirdsAtDayZero - aliveBirdsOn(date)) / startingBirdsAtDayZero * 100;
  Future<void> saveSavedAccounts(List<String> accounts) async {
    await _firebase.saveSavedAccounts(accounts);
    _savedAccounts = accounts.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    notifyListeners();
  }

  Future<void> updateFlockAccounts(String flockId, List<String> accounts) async {
    await _firebase.updateFlockAccounts(flockId, accounts);
    final updated = await _firebase.fetchFlock(flockId);
    if (updated != null) {
      final index = _flocks.indexWhere((f) => f.id == flockId);
      if (index >= 0) {
        _flocks[index] = updated;
      }
      if (_activeFlock?.id == flockId) {
        _activeFlock = updated;
        _farmConfig = FarmConfig(flockStartDate: updated.startDate, startingBirds: updated.startingBirds, breedName: updated.breedName, accounts: updated.accounts, feedItems: _feedItems);
        ExpenseCategoryConfig.setAccounts(updated.accounts);
      }
      notifyListeners();
    }
  }

  Future<void> saveFarmConfig(FarmConfig config) async { await _firebase.saveFarmConfig(config); _farmConfig = config; ExpenseCategoryConfig.setAccounts(config.accounts); notifyListeners(); }
  double get totalFeedKg=>_logs.fold(0.0,(s,e)=>s+e.feedConsumed);
  double get totalEggs=>_logs.fold(0.0,(s,e)=>s+e.totalEggs);
  double get totalTrays=>_logs.fold(0.0,(s,e)=>s+e.trays);
  double get totalExpenses=>_expenseRecords.where((e)=>e.transactionType!='credit').fold(0.0,(s,e)=>s+e.netTotal);
  double get totalCredits=>_expenseRecords.where((e)=>e.transactionType=='credit').fold(0.0,(s,e)=>s+e.netTotal);
  double get totalEggSales=>_expenseRecords.where((e)=>e.transactionType=='credit').fold(0.0,(s,e)=>s+e.netTotal);
  double get netExpense=>totalExpenses-totalCredits;
  double get averageFcr {final x=_logs.map((e)=>e.fcrByEggMass).where((e)=>e>0).toList();return x.isEmpty?0:x.reduce((a,b)=>a+b)/x.length;}
}
