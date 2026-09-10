import 'dart:async';
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

class PoultryProvider with ChangeNotifier {
  final FirebaseService _firebase = FirebaseService();
  List<PoultryLog> _logs = [];
  List<ExpenseSalesLog> _expenseRecords = [];
  List<String> _feedItems = List<String>.from(FarmConfig.defaultFeedItems);
  List<String> _expenseSubcategories = List<String>.from(ExpenseCategoryConfig.defaultSubcategories);
  List<Supplier> _suppliers = [];

  bool _isLoading = false;
  FarmConfig _farmConfig = FarmConfig.defaults;
  List<Flock> _flocks = [];
  Flock? _activeFlock;
  bool _isAdmin = false;
  String? _errorMessage;
  StreamSubscription? _authSub;
  List<PoultryLog> get logs => List.unmodifiable(_logs);
  List<ExpenseSalesLog> get expenseRecords => List.unmodifiable(_expenseRecords);
  List<String> get feedItems => List.unmodifiable(_feedItems);
  List<String> get expenseSubcategories => List.unmodifiable(_expenseSubcategories);
  List<Supplier> get suppliers => List.unmodifiable(_suppliers);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _firebase.isSignedIn;
  FarmConfig get farmConfig => _farmConfig;
  List<Flock> get flocks => List.unmodifiable(_flocks);
  Flock? get activeFlock => _activeFlock;
  bool get isAdmin => _isAdmin;
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
      _farmConfig = FarmConfig.defaults;
      return;
    }
    final currentId = _activeFlock?.id;
    final matches = _flocks.where((f) => f.id == currentId).toList();
    final selected = matches.isNotEmpty ? matches.first : _flocks.first;
    _activeFlock = selected;
    _firebase.setActiveFlock(selected.id);
    final results = await Future.wait<dynamic>([
      _firebase.fetchLogs(),
      _firebase.fetchExpenseRecords(),
      _firebase.fetchGlobalFeedItems().catchError((_) => List<String>.from(FarmConfig.defaultFeedItems)),
      _firebase.fetchGlobalExpenseSubcategories().catchError((_) => List<String>.from(ExpenseCategoryConfig.defaultSubcategories)),
      _firebase.fetchSuppliers().catchError((_) => <Supplier>[]),
    ]);

    final logs = results[0] as List<PoultryLog>;
    final expenses = results[1] as List<ExpenseSalesLog>;
    _feedItems = List<String>.from(results[2] as List<String>);
    _expenseSubcategories = List<String>.from(results[3] as List<String>);
    _suppliers = List<Supplier>.from(results[4] as List<Supplier>);
    ExpenseCategoryConfig.setSubcategories(_expenseSubcategories);
    _farmConfig = FarmConfig(
      flockStartDate: selected.startDate,
      startingBirds: selected.startingBirds,
      breedName: selected.breedName,
      accounts: selected.accounts,
      feedItems: _feedItems,
    );
    ExpenseCategoryConfig.setAccounts(_farmConfig.accounts);
    _logs = List<PoultryLog>.from(logs)..sort((a,b)=>b.date.compareTo(a.date));
    _expenseRecords = List<ExpenseSalesLog>.from(expenses)..sort((a,b)=>b.date.compareTo(a.date));
  }

  Future<void> selectFlock(String flockId) async {
    final matches = _flocks.where((f) => f.id == flockId).toList();
    final flock = matches.isNotEmpty ? matches.first : await _firebase.fetchFlock(flockId);
    if (flock == null) throw StateError('Flock not found.');
    _activeFlock = flock;
    _firebase.setActiveFlock(flock.id);
    await _reload();
  }

  Future<String> createFlock({required String name, required DateTime startDate, required int startingBirds, required String breedName, required List<String> accounts, required List<String> feedItems}) async {
    final id = await _firebase.createFlock(name: name, startDate: startDate, startingBirds: startingBirds, breedName: breedName, accounts: accounts, feedItems: feedItems);
    await _reload();
    await selectFlock(id);
    return id;
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
  Stream<List<FlockMembership>> watchFlockMembers(String flockId) => _firebase.watchMembers(flockId);
  Future<int> syncInvitedMembers(String flockId) => _firebase.syncInvitedMembers(flockId);
  Future<void> inviteFlockMember(String email) async { final id = activeFlockId; if (id.isEmpty) throw StateError('Select a flock first.'); await _firebase.inviteMember(flockId: id, email: email); }
  Future<Map<String, dynamic>?> fetchNotificationSettings() => _firebase.fetchNotificationSettings(activeFlockId);
  Future<void> saveNotificationSettings(Map<String, dynamic> data) => _firebase.saveNotificationSettings(activeFlockId, data);
  Future<Map<String, dynamic>?> fetchNotificationTemplate(String id) => _firebase.fetchNotificationTemplate(activeFlockId, id);
  Future<void> saveNotificationTemplate(String id, Map<String, dynamic> data) => _firebase.saveNotificationTemplate(activeFlockId, id, data);
  Future<void> sendFlockNotification({required String titleEn, required String titleHi, required String bodyEn, required String bodyHi, String? memberUid}) => _firebase.sendFlockNotification(flockId: activeFlockId, titleEn:titleEn, titleHi:titleHi, bodyEn:bodyEn, bodyHi:bodyHi, memberUid:memberUid);
  Future<void> updateMemberDetails(String uid, {String? mobileNumber, String? notificationLanguage}) => _firebase.updateMemberDetails(activeFlockId, uid, mobileNumber:mobileNumber, notificationLanguage:notificationLanguage);
  Future<void> updateMemberRole(String uid, String role) => _firebase.updateMemberRole(activeFlockId, uid, role);
  Future<void> removeFlockMember(String uid) async { final id = activeFlockId; if (id.isEmpty) throw StateError('Select a flock first.'); await _firebase.removeMember(id, uid); }

  void _resetLocal() {
    _logs = []; _expenseRecords = []; _flocks = []; _activeFlock = null; _feedItems = List<String>.from(FarmConfig.defaultFeedItems); _expenseSubcategories = List<String>.from(ExpenseCategoryConfig.defaultSubcategories); _suppliers = []; ExpenseCategoryConfig.setSubcategories(_expenseSubcategories); _farmConfig = FarmConfig.defaults; _isAdmin = false; _errorMessage = null; notifyListeners();
  }

  Future<void> fetchLogs() async { if(!_firebase.isSignedIn)return; _isLoading=true;notifyListeners();try{await _reload();_errorMessage=null;}catch(e){_errorMessage='Error loading Firebase data: $e';}finally{_isLoading=false;notifyListeners();} }
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
  Future<void> addExpenseRecord(ExpenseSalesLog record) async { try{await _firebase.addExpenseRecord(record);await fetchLogs();}catch(e){_errorMessage='Expense/sale was not saved: $e';notifyListeners();rethrow;} }
  Future<void> updateExpenseRecord(ExpenseSalesLog record) async { try{await _firebase.updateExpenseRecord(record);await fetchLogs();}catch(e){_errorMessage='Expense/sale was not updated: $e';notifyListeners();rethrow;} }
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
  int get totalBirds => (startingBirdsAtDayZero - totalMortality).clamp(0, startingBirdsAtDayZero);
  double get mortalityPercentage => startingBirdsAtDayZero == 0 ? 0 : totalMortality / startingBirdsAtDayZero * 100;
  double layingPercentageFor(PoultryLog log) {
    final cumulative = _logs.where((x) => !x.date.isAfter(log.date)).fold<int>(0, (sum, x) => sum + x.mortality);
    final alive = (startingBirdsAtDayZero - cumulative).clamp(0, startingBirdsAtDayZero);
    return alive == 0 ? 0 : (log.totalEggs / alive) * 100;
  }
  double get latestLayingPercentage => _logs.isEmpty ? 0 : layingPercentageFor(_logs.first);
  double get averageLayingPercentage => _logs.isEmpty ? 0 : _logs.map(layingPercentageFor).reduce((a,b)=>a+b)/_logs.length;
  int aliveBirdsOn(DateTime date) {
    final mortality = _logs.where((x) => !x.date.isAfter(date)).fold<int>(0, (sum, x) => sum + x.mortality);
    return (startingBirdsAtDayZero - mortality).clamp(0, startingBirdsAtDayZero);
  }
  double mortalityPercentageOn(DateTime date) => startingBirdsAtDayZero == 0 ? 0 : (startingBirdsAtDayZero - aliveBirdsOn(date)) / startingBirdsAtDayZero * 100;
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
