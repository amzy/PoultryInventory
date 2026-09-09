import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import '../models/expense_sales_log.dart';
import '../models/poultry_log.dart';
import 'poultry_calculation_service.dart';
import 'expense_category_config.dart';
import 'cashew_migration_parser.dart';

/// Firebase-only data layer for the Spark-plan architecture.
///
/// Business calculations are performed client-side, while Firestore Rules
/// enforce ownership, field shape, non-negative values, and calculated-field
/// invariants. Daily-log documents use deterministic date IDs so duplicates
/// are impossible at the document level.
class CashewImportResult {
  final int imported;
  final int updated;
  final int unchanged;

  const CashewImportResult({this.imported = 0, this.updated = 0, this.unchanged = 0});

  int get total => imported + updated + unchanged;
}

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

  /// Imports Cashew records using deterministic IDs derived from the source
  /// transaction ID. Existing Cashew records are deliberately updated rather
  /// than skipped so category/account/amount/type changes in the latest
  /// SQLite export repair old imports to the current app rules.
  /// Deletes only records created by the Cashew importer. Manual records
  /// use date-based IDs and are intentionally left untouched.
  Future<int> deleteImportedCashewRecords() async {
    final snapshot = await _expenses.get();
    final imported = snapshot.docs.where((doc) => doc.id.startsWith('cashew_')).toList();
    if (imported.isEmpty) return 0;

    const batchSize = 400;
    for (var start = 0; start < imported.length; start += batchSize) {
      final end = (start + batchSize < imported.length) ? start + batchSize : imported.length;
      final batch = _db.batch();
      for (final doc in imported.sublist(start, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    return imported.length;
  }

  Future<CashewImportResult> importCashewRecords(
    List<Map<String, dynamic>> records, {
    void Function(String message)? onProgress,
  }) async {
    if (records.isEmpty) return const CashewImportResult();

    onProgress?.call('Validating ${records.length} transaction(s)…');
    final parsed = CashewMigrationParser.parseRecords(records);
    var imported = 0;
    var updated = 0;
    var unchanged = 0;

    // Use one read of the user's expense collection. This is intentionally
    // simpler and more reliable on Web/Safari than a series of whereIn calls.
    onProgress?.call('Checking existing transactions…');
    final existingSnapshot = await _expenses.get().timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw StateError(
        'Timed out reading Firestore expense records after 30 seconds. ' 
        'Check the Safari console/network connection.',
      ),
    );
    final existing = <String, Map<String, dynamic>>{
      for (final doc in existingSnapshot.docs) doc.id: doc.data(),
    };

    // Small commits make Web imports observable and prevent one large request
    // from looking like an endless import.
    const writeBatchSize = 20;
    final totalBatches = (parsed.length + writeBatchSize - 1) ~/ writeBatchSize;

    for (var start = 0; start < parsed.length; start += writeBatchSize) {
      final end = (start + writeBatchSize < parsed.length)
          ? start + writeBatchSize
          : parsed.length;
      final chunk = parsed.sublist(start, end);
      final batchNumber = (start ~/ writeBatchSize) + 1;
      onProgress?.call('Writing batch $batchNumber of $totalBatches ($start–$end)…');

      final batch = _db.batch();
      var writes = 0;

      for (final item in chunk) {
        final transactionId = item['transactionId'] as String;
        final date = DateTime.tryParse(item['date'] as String);
        if (date == null) {
          throw StateError('Invalid date for transaction $transactionId.');
        }

        final source = item['source']?.toString() ?? '';
        final id = source == 'poultry_inventory_export'
            ? transactionId
            : (transactionId.startsWith('cashew_') ? transactionId : 'cashew_$transactionId');
        if (id.trim().isEmpty) {
          throw StateError('Cashew/app export contains a transaction without an ID.');
        }

        final mainCategory = item['mainCategory'] as String;
        final category = item['category'] as String;
        if (!ExpenseCategoryConfig.isValidMainCategory(mainCategory) ||
            !ExpenseCategoryConfig.isValidSubcategory(mainCategory, category)) {
          throw StateError(
            'Cashew transaction $transactionId has unsupported mapping: $mainCategory / $category.',
          );
        }

        final record = ExpenseSalesLog(
          id: id,
          date: date,
          mainCategory: mainCategory,
          category: category,
          originalCategory: item['originalCategory'] as String,
          account: item['account'] as String,
          description: (item['description'] as String).length > 500
              ? (item['description'] as String).substring(0, 500)
              : item['description'] as String,
          amount: item['amount'] as double,
          unitPrice: (item['unitPrice'] as num?)?.toDouble() ?? 0.0,
          freightCharge: (item['freightCharge'] as num?)?.toDouble() ?? 0.0,
          pricingCalculated: item['pricingCalculated'] == true,
          unit: item['unit'] as String,
          quantity: item['quantity'] as double,
          transactionType: item['transactionType'] as String,
        );

        final oldData = existing[id];
        final ref = _expenses.doc(id);

        if (oldData == null) {
          final data = record.toFirestore(includeCreatedAt: false);
          data['createdAt'] = Timestamp.fromDate(record.date);
          batch.set(ref, data);
          imported++;
          writes++;
          continue;
        }

        final existingRecord = ExpenseSalesLog.fromFirestore(oldData, id: id);
        final changed = existingRecord.date != record.date ||
            existingRecord.mainCategory != record.mainCategory ||
            existingRecord.category != record.category ||
            existingRecord.originalCategory != record.originalCategory ||
            existingRecord.account != record.account ||
            existingRecord.description != record.description ||
            existingRecord.amount != record.amount ||
            existingRecord.unitPrice != record.unitPrice ||
            existingRecord.freightCharge != record.freightCharge ||
            existingRecord.pricingCalculated != record.pricingCalculated ||
            existingRecord.unit != record.unit ||
            existingRecord.quantity != record.quantity ||
            existingRecord.transactionType != record.transactionType;

        if (!changed) {
          unchanged++;
          continue;
        }

        final data = record.toFirestore(includeCreatedAt: false);
        final createdAt = oldData['createdAt'];
        data['createdAt'] = createdAt is Timestamp ? createdAt : Timestamp.fromDate(record.date);
        batch.set(ref, data);
        updated++;
        writes++;
      }

      if (writes > 0) {
        try {
          await batch.commit().timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw StateError(
              'Timed out committing import batch $batchNumber/$totalBatches after 30 seconds. ' 
              'Open Safari Web Inspector → Console for the underlying Firestore/network error.',
            ),
          );
        } on FirebaseException catch (e) {
          // Older versions of the deployed Firestore rules do not know about
          // the newer pricing fields (unitPrice/freightCharge/pricingCalculated)
          // or optional Medical line items. If such rules are still deployed,
          // retry this atomic batch with the legacy expense shape. Once the
          // latest rules are deployed, the normal payload is used.
          if (e.code != 'permission-denied') {
            throw StateError('Firestore rejected import batch $batchNumber/$totalBatches: ${e.message ?? e.code}');
          }

          onProgress?.call(
            'Current Firestore rules rejected the new fields; retrying batch $batchNumber/$totalBatches with legacy-compatible expense fields…',
          );
          final legacyBatch = _db.batch();
          for (final item in chunk) {
            final transactionId = item['transactionId'] as String;
            final date = DateTime.tryParse(item['date'] as String);
            if (date == null) continue;
            final source = item['source']?.toString() ?? '';
            final id = source == 'poultry_inventory_export'
                ? transactionId
                : (transactionId.startsWith('cashew_') ? transactionId : 'cashew_$transactionId');
            final oldData = existing[id];
            final record = ExpenseSalesLog(
              id: id,
              date: date,
              mainCategory: item['mainCategory'] as String,
              category: item['category'] as String,
              originalCategory: item['originalCategory'] as String,
              account: item['account'] as String,
              description: (item['description'] as String).length > 500
                  ? (item['description'] as String).substring(0, 500)
                  : item['description'] as String,
              amount: item['amount'] as double,
              unit: item['unit'] as String,
              quantity: item['quantity'] as double,
              transactionType: item['transactionType'] as String,
            );
            final data = <String, dynamic>{
              'date': Timestamp.fromDate(record.date),
              'dateKey': DateFormat('yyyy-MM-dd').format(record.date),
              'mainCategory': record.mainCategory.trim().isEmpty ? 'Layer Bird' : record.mainCategory.trim(),
              'category': record.category.trim(),
              'originalCategory': record.originalCategory.trim().isEmpty ? record.category.trim() : record.originalCategory.trim(),
              'account': record.account.trim().isEmpty ? 'Amzad Khan' : record.account.trim(),
              'description': record.description,
              'amount': record.amount,
              'unit': record.unit,
              'quantity': record.quantity,
              'transactionType': record.transactionType,
              'createdAt': oldData?['createdAt'] is Timestamp
                  ? oldData!['createdAt']
                  : Timestamp.fromDate(record.date),
            };
            legacyBatch.set(_expenses.doc(id), data);
          }

          try {
            await legacyBatch.commit().timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw StateError(
                'Timed out committing legacy import batch $batchNumber/$totalBatches after 30 seconds.',
              ),
            );
          } on FirebaseException catch (legacyError) {
            throw StateError(
              'Firestore rejected import batch $batchNumber/$totalBatches: permission-denied. ' 
              'The deployed Firestore rules are incompatible with this app. ' 
              'Deploy the latest firestore.rules, then retry the import. (${legacyError.message ?? legacyError.code})',
            );
          }
        }
      }
    }

    onProgress?.call('Import finished.');
    return CashewImportResult(imported: imported, updated: updated, unchanged: unchanged);
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
