import 'package:flutter/foundation.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:intl/intl.dart';

import '../models/expense_sales_log.dart';
import '../models/poultry_log.dart';

/// Google Sheets integration for the Poultry Inventory app.
/// Every read/write goes through the authenticated Google account and the
/// configured spreadsheet. No service-account/private key is bundled.
class GoogleDriveService {
  static const String spreadsheetId = '1Fm_coXKglKKllmiHhSA3fF1Jr9P6E7oufVKg4gcA70Y';

  static const String dailyLogSheet = 'Daily_Log';
  static const String medicalSheet = 'Medical';
  static const String feedSheet = 'Feed';
  static const String gritSheet = 'Grit';
  static const String otherExpensesSheet = 'Other_Expenses';
  static const String eggSalesSheet = 'Egg_Sales';

  static const List<String> scopes = <String>[
    sheets.SheetsApi.spreadsheetsScope,
  ];

  static const String googleClientId =
      '395473159192-7i9le93o7tt2nsva4bq8dasf67i9bnrj.apps.googleusercontent.com';

  // On Web, google_sign_in_web reads the OAuth client ID from the
  // `google-signin-client_id` meta tag in web/index.html. Keeping the Web
  // constructor free of clientId/scopes avoids a second initialization path
  // and ensures GIS uses exactly the configured Web client.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: kIsWeb ? const <String>[] : scopes,
    clientId: kIsWeb ? null : googleClientId,
  );

  sheets.SheetsApi? _sheetsApi;
  bool _signedIn = false;

  bool get isSignedIn => _signedIn;

  Stream<GoogleSignInAccount?> get userChanges => _googleSignIn.onCurrentUserChanged;

  /// Returns true when the current Google account has the Sheets scope.
  /// On Web, authentication and authorization are intentionally separate.
  Future<bool> canAccessSheets() async {
    final account = _googleSignIn.currentUser;
    if (account == null) return false;
    if (!kIsWeb) return true;
    try {
      return await _googleSignIn.canAccessScopes(scopes);
    } catch (_) {
      return false;
    }
  }

  /// Completes Google Sheets authorization after the user has signed in.
  /// On Web this MUST be called directly from a user interaction because GIS
  /// may display authorization UI.
  Future<bool> authorizeSheets() async {
    final account = _googleSignIn.currentUser;
    if (account == null) {
      throw Exception('Please sign in with Google first.');
    }

    if (kIsWeb) {
      final granted = await _googleSignIn.requestScopes(scopes).timeout(
        const Duration(seconds: 45),
      );
      if (!granted) {
        throw Exception('Google Sheets permission was not granted.');
      }
    }

    final client = await _googleSignIn.authenticatedClient().timeout(
      const Duration(seconds: 20),
    );
    if (client == null) {
      throw Exception('Google authentication completed, but Sheets authorization was not available.');
    }

    _sheetsApi = sheets.SheetsApi(client);
    await _verifySheetsAccess(_sheetsApi!);
    _signedIn = true;
    return true;
  }

  Future<void> _verifySheetsAccess(sheets.SheetsApi api) async {
    await api.spreadsheets.values.get(
      spreadsheetId,
      '$dailyLogSheet!A4:M4',
      valueRenderOption: 'FORMATTED_VALUE',
    ).timeout(const Duration(seconds: 20));
    await _ensureDailyLogHeaders(api);
  }

  /// Restores an already authorized account without opening interactive UI.
  /// On Web, the GIS SDK controls authentication UI, so this method never
  /// calls signIn(). If the account exists but Sheets access is missing, the
  /// dashboard will show the separate "Allow Google Sheets" action.
  Future<bool> trySilentSignIn() async {
    try {
      if (_sheetsApi != null && _signedIn) return true;

      final account = await _googleSignIn.signInSilently().timeout(
        const Duration(seconds: 12),
      );
      if (account == null) {
        _signedIn = false;
        _sheetsApi = null;
        return false;
      }

      if (kIsWeb && !await canAccessSheets()) {
        _signedIn = false;
        _sheetsApi = null;
        return false;
      }

      final client = await _googleSignIn.authenticatedClient().timeout(
        const Duration(seconds: 20),
      );
      if (client == null) {
        _signedIn = false;
        _sheetsApi = null;
        return false;
      }

      final api = sheets.SheetsApi(client);
      await _verifySheetsAccess(api);
      _sheetsApi = api;
      _signedIn = true;
      return true;
    } catch (_) {
      _signedIn = false;
      _sheetsApi = null;
      return false;
    }
  }

  Future<sheets.SheetsApi> _api({
    bool forceReauth = false,
    bool allowInteractive = true,
  }) async {
    if (!forceReauth && _sheetsApi != null && _signedIn) {
      return _sheetsApi!;
    }

    _sheetsApi = null;
    _signedIn = false;

    // Critical Web rule: never call signIn() from application code. The Web
    // implementation requires the SDK-rendered GIS button. After sign-in,
    // Sheets authorization must be requested from a user action as well.
    if (kIsWeb) {
      throw Exception(
        'Google Sheets is not authorized. Sign in with Google, then tap "Allow Google Sheets".',
      );
    }

    GoogleSignInAccount? account = await _googleSignIn.signInSilently().timeout(
      const Duration(seconds: 12),
    );
    if (account == null && allowInteractive) {
      account = await _googleSignIn.signIn().timeout(
        const Duration(seconds: 30),
      );
    }

    if (account == null) {
      throw Exception('Google account is not connected. Tap Sign in with Google on the dashboard.');
    }

    final auth.AuthClient? client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      throw Exception('Unable to create Google Sheets authorization.');
    }

    final api = sheets.SheetsApi(client);
    await _verifySheetsAccess(api);
    _signedIn = true;
    _sheetsApi = api;
    return api;
  }

  /// Explicit Google sign-in for Android/iOS. Web uses the SDK-rendered
  /// Google button and never calls this method for authentication.
  Future<bool> signIn() async {
    if (kIsWeb) {
      throw Exception(
        'On Web, use the Google Sign-In button, then tap "Allow Google Sheets".',
      );
    }

    GoogleSignInAccount? account = _googleSignIn.currentUser;
    if (account == null) {
      account = await _googleSignIn.signIn().timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('Google Sign-In timed out. Please try again.'),
      );
    }

    if (account == null) {
      _signedIn = false;
      _sheetsApi = null;
      throw Exception('Google Sign-In was cancelled.');
    }

    final auth.AuthClient? client = await _googleSignIn.authenticatedClient().timeout(
      const Duration(seconds: 20),
    );
    if (client == null) {
      _signedIn = false;
      _sheetsApi = null;
      throw Exception('Unable to create Google Sheets authorization.');
    }

    final api = sheets.SheetsApi(client);
    await _verifySheetsAccess(api);
    _sheetsApi = api;
    _signedIn = true;
    return true;
  }

  Future<void> signOut() async {
    _sheetsApi = null;
    _signedIn = false;
    await _googleSignIn.signOut();
  }

  Future<T> _withRetry<T>(
    Future<T> Function(sheets.SheetsApi api) action, {
    bool allowInteractive = false,
  }) async {
    try {
      final api = await _api(allowInteractive: allowInteractive);
      return await action(api);
    } catch (e) {
      _sheetsApi = null;
      _signedIn = false;

      // On Web, do not start another OAuth flow from a background sync. The
      // browser requires the authorization request to originate from a user
      // interaction. The dashboard will show the authorization action.
      if (kIsWeb) {
        rethrow;
      }

      final api = await _api(forceReauth: true, allowInteractive: allowInteractive);
      return action(api);
    }
  }

  Future<List<PoultryLog>> fetchLogs() async {
    return _withRetry((api) async {
      final response = await api.spreadsheets.values.get(
        spreadsheetId,
        '$dailyLogSheet!A5:M1000',
        valueRenderOption: 'FORMATTED_VALUE',
      );

      final values = response.values ?? <List<Object?>>[];
      final logs = <PoultryLog>[];
      for (final row in values) {
        if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
        if (row.length < 13) continue;
        try {
          logs.add(PoultryLog.fromSheetRow(row));
        } catch (_) {}
      }
      return logs;
    });
  }

  Future<List<ExpenseSalesLog>> fetchExpenseRecords() async {
    return _withRetry((api) async {
      final result = <ExpenseSalesLog>[];
      for (final sheetName in <String>[
        medicalSheet,
        feedSheet,
        gritSheet,
        otherExpensesSheet,
        eggSalesSheet,
      ]) {
        final response = await api.spreadsheets.values.get(
          spreadsheetId,
          '$sheetName!A2:Z1000',
          valueRenderOption: 'FORMATTED_VALUE',
        );
        final values = response.values ?? <List<Object?>>[];
        for (final row in values) {
          if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
          final mapped = _mapExpenseRow(sheetName, row);
          if (mapped != null) result.add(mapped);
        }
      }
      result.sort((a, b) => b.date.compareTo(a.date));
      return result;
    });
  }

  Future<void> _ensureDailyLogHeaders(sheets.SheetsApi api) async {
    await api.spreadsheets.values.update(
      sheets.ValueRange(values: <List<Object?>>[
        <Object?>[
          'Date',
          'Flock Age (Days)',
          'Starting Birds',
          'Mortality (Deaths)',
          'Ending Birds',
          'Trays (30 Eggs)',
          'Total Eggs',
          'Avg Tray Weight (g)',
          'Feed Consumed (kg)',
          'Stone/Grit Consumed (kg)',
          'Water Intake (L)',
          'FCR (Feed kg / Tray)',
          'Laying Percentage (%)',
        ],
      ]),
      spreadsheetId,
      '$dailyLogSheet!A4:M4',
      valueInputOption: 'USER_ENTERED',
    );
  }

  /// Writes a complete Daily_Log row to Google Sheets.
  ///
  /// Uses the Sheets append endpoint so blank rows cannot cause an overwrite.
  /// The response tells us which row was actually written; formulas are then
  /// placed into that exact row and the row is read back before this method
  /// reports success.
  Future<void> appendDailyLog(PoultryLog log) async {
    final api = await _api(allowInteractive: true);
    final date = DateFormat('yyyy-MM-dd').format(log.date);

    final response = await api.spreadsheets.values.append(
      sheets.ValueRange(values: <List<Object?>>[
        <Object?>[
          date,
          log.flockAge,
          log.startingBirds,
          log.mortality,
          log.endingBirds,
          log.trays,
          log.totalEggs,
          log.avgTrayWeight,
          log.feedConsumed,
          log.stoneGritConsumed,
          log.waterIntake,
          log.automatedFCR,
          log.layingPercentage,
        ],
      ]),
      spreadsheetId,
      '$dailyLogSheet!A:M',
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
      includeValuesInResponse: true,
      responseValueRenderOption: 'FORMATTED_VALUE',
    );

    final updatedRange = response.updates?.updatedRange;
    final rowNumber = _rowNumberFromRange(updatedRange);
    if (rowNumber == null) {
      throw Exception('Google Sheets saved the Daily Log but did not return the written row.');
    }

    // Keep the sheet formulas authoritative, but write them into the exact
    // row returned by Sheets rather than guessing a row from values.length.
    final ageFormula =
        '=IF(A$rowNumber="","",Settings!\$E\$4+(A$rowNumber-Settings!\$E\$3))';
    final fcrFormula = '=IFERROR(I$rowNumber/F$rowNumber,"")';
    final layingFormula = '=IFERROR(G$rowNumber/E$rowNumber*100,"")';

    await api.spreadsheets.values.update(
      sheets.ValueRange(values: <List<Object?>>[<Object?>[ageFormula]]),
      spreadsheetId,
      '$dailyLogSheet!B$rowNumber',
      valueInputOption: 'USER_ENTERED',
    );
    await api.spreadsheets.values.update(
      sheets.ValueRange(values: <List<Object?>>[<Object?>[fcrFormula]]),
      spreadsheetId,
      '$dailyLogSheet!L$rowNumber',
      valueInputOption: 'USER_ENTERED',
    );
    await api.spreadsheets.values.update(
      sheets.ValueRange(values: <List<Object?>>[<Object?>[layingFormula]]),
      spreadsheetId,
      '$dailyLogSheet!M$rowNumber',
      valueInputOption: 'USER_ENTERED',
    );

    await _verifyDailyLogWrite(api, rowNumber, log);
  }

  /// Appends an expense/sale to the correct tab and verifies that Google
  /// Sheets actually contains the submitted values before returning.
  ///
  /// Unlike the old write path, this method does not blindly retry an append
  /// after an uncertain network/API failure because that can create duplicates.
  Future<void> appendExpenseRecord(ExpenseSalesLog record) async {
    final api = await _api(allowInteractive: true);
    final sheet = record.category;
    final row = await _buildExpenseRowFromHeaders(api, sheet, record);

    final response = await api.spreadsheets.values.append(
      sheets.ValueRange(values: <List<Object?>>[row]),
      spreadsheetId,
      '$sheet!A:Z',
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
      includeValuesInResponse: true,
      responseValueRenderOption: 'FORMATTED_VALUE',
    );

    final updatedRange = response.updates?.updatedRange;
    final rowNumber = _rowNumberFromRange(updatedRange);
    if (rowNumber == null) {
      throw Exception('Google Sheets saved the record but did not return the written row.');
    }

    await _verifyExpenseWrite(api, sheet, rowNumber, record);
  }

  Future<List<Object?>> _buildExpenseRowFromHeaders(
    sheets.SheetsApi api,
    String sheetName,
    ExpenseSalesLog record,
  ) async {
    switch (sheetName) {
      case medicalSheet:
      case feedSheet:
      case gritSheet:
      case otherExpensesSheet:
      case eggSalesSheet:
        break;
      default:
        throw Exception('Unsupported expense category: $sheetName');
    }

    final response = await api.spreadsheets.values.get(
      spreadsheetId,
      '$sheetName!A1:Z3',
      valueRenderOption: 'FORMATTED_VALUE',
    );
    final rows = response.values ?? <List<Object?>>[];
    final headers = rows.isNotEmpty ? rows.first : <Object?>[];

    // If the tab has recognizable headers, map by header name so a column
    // rearrangement does not silently put an amount/quantity in the wrong
    // column. Fall back to the existing layouts for older tabs without
    // headers.
    if (headers.isNotEmpty) {
      final normalized = headers.map((e) => _normalizeHeader(e)).toList();
      final hasRecognized = normalized.any((h) =>
          h.contains('date') || h.contains('amount') || h.contains('quantity') ||
          h.contains('description') || h.contains('unit') || h.contains('tray'));
      if (hasRecognized) {
        final width = normalized.length.clamp(6, 26).toInt();
        final row = List<Object?>.filled(width, '');
        void put(List<String> names, Object? value) {
          for (var i = 0; i < normalized.length; i++) {
            if (names.any((name) => normalized[i].contains(name))) {
              row[i] = value;
              return;
            }
          }
        }

        put(['date'], _date(record.date));
        put(['category', 'type'], record.category);
        put(['description', 'particular', 'details', 'item'], record.description);
        put(['amount', 'price', 'cost', 'total', 'sales'], record.amount);
        put(['unit', 'units'], record.unit);
        put(['quantity', 'qty', 'bags', 'kg', 'litre', 'liter', 'trays'], record.quantity);
        return row;
      }
    }

    switch (sheetName) {
      case medicalSheet:
        return <Object?>[
          _date(record.date), record.description, '', record.quantity,
          record.unit, record.amount, '', '',
        ];
      case feedSheet:
        return <Object?>[
          _date(record.date), record.description, '', record.quantity,
          '', record.amount, '', '',
        ];
      case gritSheet:
        return <Object?>[
          _date(record.date), record.description, '', record.quantity,
          record.amount, '',
        ];
      case otherExpensesSheet:
        return <Object?>[
          _date(record.date), record.description, record.description,
          record.quantity, record.amount, '',
        ];
      case eggSalesSheet:
        return <Object?>[
          _date(record.date), '', record.quantity, 30, '', '',
          record.amount, '', '', '',
        ];
      default:
        throw Exception('Unsupported expense category: $sheetName');
    }
  }

  String _normalizeHeader(Object? value) =>
      value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ?? '';

  int? _rowNumberFromRange(String? range) {
    if (range == null || range.isEmpty) return null;
    final match = RegExp(r'![A-Z]+(\d+)(?::[A-Z]+(\d+))?$', caseSensitive: false).firstMatch(range);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  Future<void> _verifyDailyLogWrite(
    sheets.SheetsApi api,
    int rowNumber,
    PoultryLog expected,
  ) async {
    final response = await api.spreadsheets.values.get(
      spreadsheetId,
      '$dailyLogSheet!A$rowNumber:M$rowNumber',
      valueRenderOption: 'UNFORMATTED_VALUE',
    );
    final row = response.values?.isNotEmpty == true ? response.values!.first : <Object?>[];
    if (row.length < 13 || row[0].toString() != DateFormat('yyyy-MM-dd').format(expected.date)) {
      throw Exception('Daily Log could not be verified after saving to Google Sheets.');
    }
    if (_asDouble(row[2]) != expected.startingBirds ||
        _asDouble(row[3]) != expected.mortality ||
        _asDouble(row[4]) != expected.endingBirds ||
        _asDouble(row[5]) != expected.trays ||
        _asDouble(row[6]) != expected.totalEggs ||
        _asDouble(row[8]) != expected.feedConsumed ||
        _asDouble(row[9]) != expected.stoneGritConsumed ||
        _asDouble(row[10]) != expected.waterIntake) {
      throw Exception('Daily Log verification failed: saved values do not match the submitted entry.');
    }
  }

  Future<void> _verifyExpenseWrite(
    sheets.SheetsApi api,
    String sheetName,
    int rowNumber,
    ExpenseSalesLog expected,
  ) async {
    final response = await api.spreadsheets.values.get(
      spreadsheetId,
      '$sheetName!A$rowNumber:Z$rowNumber',
      valueRenderOption: 'UNFORMATTED_VALUE',
    );
    final row = response.values?.isNotEmpty == true ? response.values!.first : <Object?>[];
    if (row.isEmpty || _parseDate(row[0]) == null) {
      throw Exception('$sheetName could not be verified after saving to Google Sheets.');
    }
    if (DateFormat('yyyy-MM-dd').format(_parseDate(row[0])!) != DateFormat('yyyy-MM-dd').format(expected.date)) {
      throw Exception('$sheetName verification failed: saved date does not match the submitted entry.');
    }

    // Verify the key numeric value according to the existing/fallback layouts.
    var amountIndex = -1;
    var quantityIndex = -1;
    final headerResponse = await api.spreadsheets.values.get(
      spreadsheetId,
      '$sheetName!A1:Z1',
      valueRenderOption: 'FORMATTED_VALUE',
    );
    final headers = headerResponse.values?.isNotEmpty == true
        ? headerResponse.values!.first.map(_normalizeHeader).toList()
        : <String>[];
    for (var i = 0; i < headers.length; i++) {
      if (amountIndex < 0 && (headers[i].contains('amount') || headers[i].contains('price') || headers[i].contains('cost') || headers[i].contains('total') || headers[i].contains('sales'))) {
        amountIndex = i;
      }
      if (quantityIndex < 0 && (headers[i].contains('quantity') || headers[i].contains('qty') || headers[i].contains('bags') || headers[i].contains('trays'))) {
        quantityIndex = i;
      }
    }
    // Fallback layouts used when the tab has no recognizable header row.
    if (amountIndex < 0) {
      amountIndex = switch (sheetName) {
        medicalSheet => 5,
        feedSheet => 5,
        gritSheet => 4,
        otherExpensesSheet => 4,
        eggSalesSheet => 6,
        _ => -1,
      };
    }
    if (quantityIndex < 0) {
      quantityIndex = switch (sheetName) {
        medicalSheet => 3,
        feedSheet => 3,
        gritSheet => 3,
        otherExpensesSheet => 3,
        eggSalesSheet => 2,
        _ => -1,
      };
    }
    if (amountIndex >= row.length || quantityIndex >= row.length ||
        (_asDouble(row[amountIndex]) - expected.amount).abs() > 0.000001 ||
        (_asDouble(row[quantityIndex]) - expected.quantity).abs() > 0.000001) {
      throw Exception('$sheetName verification failed: saved amount/quantity does not match the submitted entry.');
    }
  }

  double _asDouble(Object? value) => double.tryParse(value?.toString() ?? '') ?? 0.0;

  DateTime? _parseDate(Object? value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    final text = value.toString();
    try {
      return DateFormat('yyyy-MM-dd').parse(text);
    } catch (_) {
      try {
        return DateTime.parse(text);
      } catch (_) {
        return null;
      }
    }
  }

  String _date(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
}
