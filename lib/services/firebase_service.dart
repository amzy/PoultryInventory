import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/expense_sales_log.dart';
import '../models/poultry_log.dart';
import 'poultry_calculation_service.dart';

/// Firebase-only data layer for the Spark-plan architecture.
///
/// Business calculations are performed client-side, while Firestore Rules
/// enforce ownership, field shape, non-negative values, and calculated-field
/// invariants. Daily-log documents use deterministic date IDs so duplicates
/// are impossible at the document level.
class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn.instance;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;
  Stream<User?> get authChanges => _auth.authStateChanges();

  String get _uid {
    final user = currentUser;
    if (user == null) throw StateError('Please sign in first.');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _daily =>
      _db.collection('users').doc(_uid).collection('daily_logs');

  CollectionReference<Map<String, dynamic>> get _expenses =>
      _db.collection('users').doc(_uid).collection('expense_records');

  DocumentReference<Map<String, dynamic>> get _farmConfig =>
      _db.collection('users').doc(_uid).collection('settings').doc('farm');

  Future<void> initializeGoogle() async {
    if (!kIsWeb) await _google.initialize();
  }

  Future<void> signIn() async {
    if (!kIsWeb) await _google.initialize();
    if (kIsWeb) {
      await _auth.signInWithPopup(GoogleAuthProvider());
      return;
    }
    final account = await _google.authenticate();
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw StateError('Google Sign-In did not return an ID token.');
    }
    final credential = GoogleAuthProvider.credential(idToken: token);
    await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    if (!kIsWeb) await _google.signOut();
    await _auth.signOut();
  }

  Future<List<PoultryLog>> fetchLogs() async {
    final snapshot = await _daily.orderBy('dateKey', descending: true).get();
    final logs = snapshot.docs.map((d) => PoultryLog.fromFirestore(d.data())).toList();
    await _ensureFarmBootstrapConfig(logs);
    return logs;
  }

  Future<List<ExpenseSalesLog>> fetchExpenseRecords() async {
    final snapshot = await _expenses.orderBy('dateKey', descending: true).get();
    return snapshot.docs
        .map((d) => ExpenseSalesLog.fromFirestore(d.data(), id: d.id))
        .toList();
  }

  String _dateKey(DateTime date) => PoultryCalculationService.dateKey(date);

  Future<PoultryLog?> _findPreviousLog(DateTime date) async {
    final key = _dateKey(date);
    final snapshot = await _daily
        .where('dateKey', isLessThan: key)
        .orderBy('dateKey', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return PoultryLog.fromFirestore(snapshot.docs.first.data());
  }

  Future<List<PoultryLog>> _findFutureLogs(String insertedKey) async {
    final snapshot = await _daily
        .where('dateKey', isGreaterThan: insertedKey)
        .orderBy('dateKey')
        .get();
    return snapshot.docs
        .map((d) => PoultryLog.fromFirestore(d.data()))
        .toList();
  }

  Future<void> _ensureFarmBootstrapConfig(List<PoultryLog> logs) async {
    final config = await _farmConfig.get();
    if (config.exists) return;
    if (logs.isEmpty) return;
    final earliest = logs.reduce((a, b) => a.date.isBefore(b.date) ? a : b);
    await _farmConfig.set({
      'initialized': true,
      'openingBirds': 5200,
      'firstLogDateKey': _dateKey(earliest.date),
    });
  }

  /// Adds one Daily Log and repairs all later logs when the entry is backdated.
  ///
  /// The target document ID is yyyy-MM-dd, so a duplicate date is rejected by
  /// a transaction even if two app instances attempt the same date together.
  Future<void> addDailyLog(PoultryLog input) async {
    final normalized = PoultryCalculationService.normalizeDate(input.date);
    final key = _dateKey(normalized);
    if (normalized.isAfter(PoultryCalculationService.normalizeDate(DateTime.now()))) {
      throw StateError('Daily Log date cannot be in the future.');
    }

    final previous = await _findPreviousLog(normalized);

    final targetRef = _daily.doc(key);
    final previousRef = previous == null ? null : _daily.doc(_dateKey(previous.date));

    final committed = await _db.runTransaction<PoultryLog>((tx) async {
      final existing = await tx.get(targetRef);
      if (existing.exists) {
        throw StateError('A Daily Log already exists for $key.');
      }

      // Re-read the selected previous document inside the transaction so a
      // concurrent change to that document causes Firestore to retry the
      // transaction instead of silently accepting stale bird counts.
      PoultryLog? currentPrevious;
      if (previousRef != null) {
        final previousSnapshot = await tx.get(previousRef);
        if (!previousSnapshot.exists) {
          throw StateError('The previous Daily Log no longer exists. Please retry.');
        }
        currentPrevious = PoultryLog.fromFirestore(previousSnapshot.data()!);
        if (currentPrevious.endingBirds != previous!.endingBirds) {
          throw StateError('Daily Logs changed while saving. Please retry.');
        }
      } else {
        final configSnapshot = await tx.get(_farmConfig);
        if (!configSnapshot.exists) {
          tx.set(_farmConfig, {
            'initialized': true,
            'openingBirds': 5200,
            'firstLogDateKey': key,
          });
        } else {
          final config = configSnapshot.data()!;
          if (config['firstLogDateKey']?.toString() != key) {
            throw StateError('This date is before the first Daily Log. Please choose a date on or after the first log.');
          }
        }
      }

      final finalCalculated = PoultryCalculationService.calculate(
        input: input.copyWith(date: normalized),
        previous: currentPrevious,
      );
      tx.set(targetRef, finalCalculated.toFirestore());
      return finalCalculated;
    });

    // Re-read future logs after the transaction so repairs are based on the
    // exact previous ending-bird count that was committed.
    final future = await _findFutureLogs(key);
    final repairedFuture = <PoultryLog>[];
    var chainPrevious = committed;
    for (final old in future) {
      final updated = PoultryCalculationService.recalculateFromPrevious(
        input: old,
        previous: chainPrevious,
      );
      repairedFuture.add(updated);
      chainPrevious = updated;
    }
    await _writeFutureRepairs(repairedFuture);
  }

  /// Updates an existing Daily Log. The date remains immutable and all later
  /// logs are recalculated so the bird-count chain stays consistent.
  Future<void> updateDailyLog(PoultryLog input) async {
    final normalized = PoultryCalculationService.normalizeDate(input.date);
    final key = _dateKey(normalized);
    if (normalized.isAfter(PoultryCalculationService.normalizeDate(DateTime.now()))) {
      throw StateError('Daily Log date cannot be in the future.');
    }

    final targetRef = _daily.doc(key);
    final previous = await _findPreviousLog(normalized);
    final previousRef = previous == null ? null : _daily.doc(_dateKey(previous.date));

    final committed = await _db.runTransaction<PoultryLog>((tx) async {
      final existing = await tx.get(targetRef);
      if (!existing.exists) throw StateError('Daily Log not found for $key.');

      PoultryLog? currentPrevious;
      if (previousRef != null) {
        final snap = await tx.get(previousRef);
        if (!snap.exists) throw StateError('Previous Daily Log no longer exists. Please retry.');
        currentPrevious = PoultryLog.fromFirestore(snap.data()!);
      } else {
        final configSnapshot = await tx.get(_farmConfig);
        final config = configSnapshot.data();
        if (config == null || config['firstLogDateKey']?.toString() != key) {
          throw StateError('Farm opening configuration is missing. Refresh the app and try again.');
        }
      }

      final calculated = PoultryCalculationService.calculate(
        input: input.copyWith(date: normalized),
        previous: currentPrevious,
      );
      tx.set(targetRef, calculated.toFirestore());
      return calculated;
    });

    final future = await _findFutureLogs(key);
    final repaired = <PoultryLog>[];
    var chainPrevious = committed;
    for (final old in future) {
      final updated = PoultryCalculationService.recalculateFromPrevious(
        input: old,
        previous: chainPrevious,
      );
      repaired.add(updated);
      chainPrevious = updated;
    }
    await _writeFutureRepairs(repaired);
  }

  /// Firestore Rules use one getAfter() call to verify each chain link. Keep
  /// batches below the 20 document-access-call rule limit.
  Future<void> _writeFutureRepairs(List<PoultryLog> logs) async {
    if (logs.isEmpty) return;
    const batchSize = 15;
    for (var start = 0; start < logs.length; start += batchSize) {
      final end = (start + batchSize < logs.length) ? start + batchSize : logs.length;
      final batch = _db.batch();
      for (final log in logs.sublist(start, end)) {
        batch.set(_daily.doc(_dateKey(log.date)), log.toFirestore());
      }
      await batch.commit();
    }
  }

  Future<int> importCashewRecords(List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return 0;

    // Imported records use the original Cashew transaction ID as the Firestore
    // document suffix. This makes the import safe to run more than once: an
    // already-imported Cashew transaction is skipped.
    final pending = <Map<String, dynamic>>[];
    for (final item in records) {
      final transactionId = item['transactionId']?.toString().trim() ?? '';
      final dateText = item['date']?.toString() ?? '';
      final category = item['originalCategory']?.toString().trim().isNotEmpty == true
          ? item['originalCategory'].toString().trim()
          : (item['category']?.toString() ?? '');
      final description = item['description']?.toString() ?? '';
      final amount = (item['amount'] as num?)?.toDouble() ?? -1;
      final unit = item['unit']?.toString() ?? 'rupees';
      final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
      if (transactionId.isEmpty || dateText.isEmpty || amount < 0 || quantity < 0) continue;
      
      final date = DateTime.tryParse(dateText);
      if (date == null) continue;
      pending.add({
        'id': 'cashew_$transactionId',
        'record': ExpenseSalesLog(
          date: date,
          mainCategory: item['mainCategory']?.toString().trim().isNotEmpty == true
              ? item['mainCategory'].toString()
              : 'Cashew',
          category: category,
          description: description.length > 500 ? description.substring(0, 500) : description,
          amount: amount,
          unit: unit,
          quantity: quantity,
        ),
      });
    }

    var imported = 0;
    for (var start = 0; start < pending.length; start += 400) {
      final end = (start + 400 < pending.length) ? start + 400 : pending.length;
      final chunk = pending.sublist(start, end);
      final existing = <String>{};

      // Rules keep createdAt immutable, so we only create missing imported
      // documents instead of overwriting them on a repeat import.
      for (final item in chunk) {
        final snap = await _expenses.doc(item['id'] as String).get();
        if (snap.exists) existing.add(item['id'] as String);
      }

      final batch = _db.batch();
      var batchCount = 0;
      for (final item in chunk) {
        final id = item['id'] as String;
        if (existing.contains(id)) continue;
        batch.set(_expenses.doc(id), (item['record'] as ExpenseSalesLog).toFirestore());
        batchCount++;
      }
      if (batchCount > 0) {
        await batch.commit();
        imported += batchCount;
      }
    }
    return imported;
  }

  Future<void> updateExpenseRecord(ExpenseSalesLog record) async {
    if (record.id == null || record.id!.trim().isEmpty) {
      throw StateError('Expense record ID is missing.');
    }
    if (record.amount < 0 || record.quantity < 0) {
      throw StateError('Amount and quantity cannot be negative.');
    }
    if (record.mainCategory.trim().isEmpty || record.category.trim().isEmpty) {
      throw StateError('Main category and category are required.');
    }
    final ref = _expenses.doc(record.id);
    final existing = await ref.get();
    if (!existing.exists) throw StateError('Expense record no longer exists.');
    final data = record.toFirestore(includeCreatedAt: false);
    data['createdAt'] = existing.data()?['createdAt'];
    await ref.set(data);
  }

  Future<void> addExpenseRecord(ExpenseSalesLog record) async {
    if (record.amount < 0 || record.quantity < 0) {
      throw StateError('Amount and quantity cannot be negative.');
    }
    if (record.category.trim().isEmpty) {
      throw StateError('Expense/Sales category is required.');
    }
    if (record.mainCategory.trim().isEmpty) {
      throw StateError('Main category is required.');
    }

    // Randomized microsecond suffix avoids collisions when multiple records
    // are created on the same day. The date is still stored separately for
    // querying and reporting.
    final key = '${_dateKey(record.date)}_${DateTime.now().microsecondsSinceEpoch}';
    await _expenses.doc(key).set(record.toFirestore());
  }
}
