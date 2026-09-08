import 'dart:async';
import 'package:flutter/material.dart';
import '../models/poultry_log.dart';
import '../models/expense_sales_log.dart';
import '../services/google_drive_service.dart';

class PoultryProvider with ChangeNotifier {
  final GoogleDriveService _driveService = GoogleDriveService();

  List<PoultryLog> _logs = [];
  List<ExpenseSalesLog> _expenseRecords = [];
  bool _isLoading = false;
  bool _isSigningIn = false;
  String? _errorMessage;
  bool _googleAuthenticated = false;
  StreamSubscription? _googleUserSubscription;

  List<PoultryLog> get logs => List.unmodifiable(_logs);
  List<ExpenseSalesLog> get expenseRecords => List.unmodifiable(_expenseRecords);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isGoogleSignedIn => _driveService.isSignedIn;
  bool get isSigningIn => _isSigningIn;
  bool get isGoogleAuthenticated => _googleAuthenticated || _driveService.isSignedIn;
  Future<bool> get canAccessGoogleSheets => _driveService.canAccessSheets();

  PoultryProvider() {
    _googleUserSubscription = _driveService.userChanges.listen((account) async {
      _googleAuthenticated = account != null;
      if (account == null) {
        _errorMessage = null;
      } else {
        _errorMessage = null;
      }
      notifyListeners();
    });
    _loadDataOnStartup();
  }

  @override
  void dispose() {
    _googleUserSubscription?.cancel();
    super.dispose();
  }

  /// On every app launch, first try the previously authorized Google account
  /// silently. If Google authentication is not available yet (for example on
  /// the first-ever launch), the dashboard remains usable and shows the Sign
  /// in with Google action. Once signed in, the same method immediately loads
  /// all data from Google Sheets.
  Future<void> _loadDataOnStartup() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final connected = await _driveService.trySilentSignIn();
      if (!connected) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      await _reloadFromGoogleSheet();
    } catch (e) {
      _errorMessage = 'Unable to sync Google Sheet on startup: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _reloadFromGoogleSheet() async {
    final results = await Future.wait([
      _driveService.fetchLogs(),
      _driveService.fetchExpenseRecords(),
    ]);

    _logs = (results[0] as List<PoultryLog>)
      ..sort((a, b) => b.date.compareTo(a.date));
    _expenseRecords = (results[1] as List<ExpenseSalesLog>)
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> fetchLogs() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _reloadFromGoogleSheet();
    } catch (e) {
      _errorMessage = 'Error fetching Google Sheet data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addLog(PoultryLog log) async {
    _errorMessage = null;
    notifyListeners();
    try {
      final duplicate = _logs.any((existing) =>
          existing.date.year == log.date.year &&
          existing.date.month == log.date.month &&
          existing.date.day == log.date.day);
      if (duplicate) {
        throw Exception(
          'A Daily Log already exists for ${log.date.year.toString().padLeft(4, '0')}-${log.date.month.toString().padLeft(2, '0')}-${log.date.day.toString().padLeft(2, '0')}. Choose another date.',
        );
      }
      await _driveService.appendDailyLog(log);
      await fetchLogs();
    } catch (e) {
      _errorMessage = 'Daily log was not synced to Google Sheets: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addExpenseRecord(ExpenseSalesLog record) async {
    _errorMessage = null;
    notifyListeners();
    try {
      await _driveService.appendExpenseRecord(record);
      await fetchLogs();
    } catch (e) {
      _errorMessage = 'Expense/sale was not synced to Google Sheets: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signInToGoogle() async {
    if (_isSigningIn) return;
    _isSigningIn = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _driveService.signIn();
      await _reloadFromGoogleSheet();
      _googleAuthenticated = true;
    } catch (e) {
      _errorMessage = 'Google Sheets sign-in failed: $e';
    } finally {
      _isSigningIn = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> authorizeGoogleSheets() async {
    if (_isSigningIn) return;
    _isSigningIn = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _driveService.authorizeSheets();
      await _reloadFromGoogleSheet();
      _googleAuthenticated = true;
    } catch (e) {
      _errorMessage = 'Google Sheets permission failed: $e';
    } finally {
      _isSigningIn = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOutOfGoogle() async {
    await _driveService.signOut();
    _logs = [];
    _expenseRecords = [];
    _errorMessage = null;
    notifyListeners();
  }

  int get totalBirds => _logs.isNotEmpty ? _logs.first.endingBirds : 0;
  int get totalMortality => _logs.fold(0, (sum, item) => sum + item.mortality);

  double get averageLayingPercentage => _logs.isEmpty
      ? 0.0
      : _logs.map((e) => e.layingPercentage).reduce((a, b) => a + b) /
          _logs.length;

  double get totalFeedKg => _logs.fold(0.0, (sum, item) => sum + item.feedConsumed);
  double get totalEggs => _logs.fold(0.0, (sum, item) => sum + item.totalEggs);
  double get totalTrays => _logs.fold(0.0, (sum, item) => sum + item.trays);

  double get totalExpenses => _expenseRecords
      .where((e) => e.category != 'Egg_Sales')
      .fold(0.0, (sum, item) => sum + item.amount);

  double get totalEggSales => _expenseRecords
      .where((e) => e.category == 'Egg_Sales')
      .fold(0.0, (sum, item) => sum + item.amount);

  double get netExpense => totalExpenses - totalEggSales;

  double get averageFcr => _logs.isEmpty
      ? 0.0
      : _logs.map((e) => e.automatedFCR).where((e) => e > 0).isEmpty
          ? 0.0
          : _logs.map((e) => e.automatedFCR).where((e) => e > 0).reduce((a, b) => a + b) /
              _logs.map((e) => e.automatedFCR).where((e) => e > 0).length;
}
