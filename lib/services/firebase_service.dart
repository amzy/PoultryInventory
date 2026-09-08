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
    return snapshot.docs
        .map((d) => PoultryLog.fromFirestore(d.data()))
        .toList();
  }

  Future<List<ExpenseSalesLog>> fetchExpenseRecords() async {
    final snapshot = await _expenses.orderBy('dateKey', descending: true).get();
    return snapshot.docs
        .map((d) => ExpenseSalesLog.fromFirestore(d.data()))
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

  Future<void> addExpenseRecord(ExpenseSalesLog record) async {
    if (record.amount < 0 || record.quantity < 0) {
      throw StateError('Amount and quantity cannot be negative.');
    }
    if (record.category.trim().isEmpty) {
      throw StateError('Expense/Sales category is required.');
    }

    // Randomized microsecond suffix avoids collisions when multiple records
    // are created on the same day. The date is still stored separately for
    // querying and reporting.
    final key = '${_dateKey(record.date)}_${DateTime.now().microsecondsSinceEpoch}';
    await _expenses.doc(key).set(record.toFirestore());
  }
}
