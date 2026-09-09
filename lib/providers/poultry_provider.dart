import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import '../models/poultry_log.dart';
import '../models/expense_sales_log.dart';
import '../services/firebase_service.dart';

class PoultryProvider with ChangeNotifier {
  final FirebaseService _firebase = FirebaseService();
  List<PoultryLog> _logs = [];
  List<ExpenseSalesLog> _expenseRecords = [];
  bool _isLoading = false;
  bool _isSigningIn = false;
  String? _errorMessage;
  StreamSubscription? _authSub;
  List<PoultryLog> get logs => List.unmodifiable(_logs);
  List<ExpenseSalesLog> get expenseRecords => List.unmodifiable(_expenseRecords);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isGoogleSignedIn => _firebase.isSignedIn;
  bool get isGoogleAuthenticated => _firebase.isSignedIn;
  bool get isSigningIn => _isSigningIn;
  PoultryProvider() { _authSub = _firebase.authChanges.listen((_) { notifyListeners(); if (_firebase.isSignedIn) fetchLogs(); }); _startup(); }
  Future<void> _startup() async { _isLoading=true; notifyListeners(); try { if (_firebase.isSignedIn) await _reload(); } catch(e){_errorMessage='Unable to load Firebase data: $e';} finally{_isLoading=false;notifyListeners();} }
  Future<void> _reload() async { final logs = await _firebase.fetchLogs(); final expenses = await _firebase.fetchExpenseRecords(); _logs = List<PoultryLog>.from(logs)..sort((a,b)=>b.date.compareTo(a.date)); _expenseRecords = List<ExpenseSalesLog>.from(expenses)..sort((a,b)=>b.date.compareTo(a.date)); }
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
  Future<CashewImportResult> importCashewRecords(List<Map<String, dynamic>> records) async {
    try {
      final imported = await _firebase.importCashewRecords(records);
      await fetchLogs();
      _errorMessage = null;
      return imported;
    } catch (e) {
      _errorMessage = 'Cashew import failed: $e';
      notifyListeners();
      rethrow;
    }
  }
  Future<void> signInToGoogle() async {if(_isSigningIn)return;_isSigningIn=true;notifyListeners();try{await _firebase.signIn();await _reload();}catch(e){_errorMessage='Firebase sign-in failed: $e';}finally{_isSigningIn=false;notifyListeners();}}
  Future<void> authorizeGoogleSheets() async {}
  Future<void> signOutOfGoogle() async {await _firebase.signOut();_logs=[];_expenseRecords=[];notifyListeners();}
  @override void dispose(){_authSub?.cancel();super.dispose();}
  int get totalBirds=>_logs.isNotEmpty?_logs.first.endingBirds:0;
  int get totalMortality=>_logs.fold(0,(s,e)=>s+e.mortality);
  double get averageLayingPercentage=>_logs.isEmpty?0:_logs.map((e)=>e.layingPercentage).reduce((a,b)=>a+b)/_logs.length;
  double get totalFeedKg=>_logs.fold(0.0,(s,e)=>s+e.feedConsumed);
  double get totalEggs=>_logs.fold(0.0,(s,e)=>s+e.totalEggs);
  double get totalTrays=>_logs.fold(0.0,(s,e)=>s+e.trays);
  double get totalExpenses=>_expenseRecords.where((e)=>e.transactionType!='credit').fold(0.0,(s,e)=>s+e.amount);
  double get totalCredits=>_expenseRecords.where((e)=>e.transactionType=='credit').fold(0.0,(s,e)=>s+e.amount);
  double get totalEggSales=>_expenseRecords.where((e)=>e.category=='Egg_Sales' || e.transactionType=='credit').fold(0.0,(s,e)=>s+e.amount);
  double get netExpense=>totalExpenses-totalCredits;
  double get averageFcr {final x=_logs.map((e)=>e.automatedFCR).where((e)=>e>0).toList();return x.isEmpty?0:x.reduce((a,b)=>a+b)/x.length;}
}
