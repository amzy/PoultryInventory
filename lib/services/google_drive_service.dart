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
  static const String spreadsheetId = '15ubhr2iPCXIwc4umiiqNESpOai12qPPN';

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
  Future<void> appendDailyLog(PoultryLog log) async {
    await _withRetry((api) async {
      final existing = await api.spreadsheets.values.get(
        spreadsheetId,
        '$dailyLogSheet!A5:M1000',
        valueRenderOption: 'FORMATTED_VALUE',
      );
      final rows = existing.values ?? <List<Object?>>[];
      final rowNumber = rows.length + 5;

      final date = DateFormat('yyyy-MM-dd').format(log.date);
      final ageFormula =
          '=IF(A$rowNumber="","",Settings!\$E\$4+(A$rowNumber-Settings!\$E\$3))';
      final fcrFormula = '=IFERROR(I$rowNumber/F$rowNumber,"")';
      final layingFormula = '=IFERROR(G$rowNumber/E$rowNumber*100,"")';

      final values = <Object?>[
        date,
        ageFormula,
        log.startingBirds,
        log.mortality,
        log.endingBirds,
        log.trays,
        log.totalEggs,
        log.avgTrayWeight,
        log.feedConsumed,
        log.stoneGritConsumed,
        log.waterIntake,
        fcrFormula,
        layingFormula,
      ];

      await api.spreadsheets.values.update(
        sheets.ValueRange(
          range: '$dailyLogSheet!A$rowNumber:M$rowNumber',
          values: <List<Object?>>[values],
        ),
        spreadsheetId,
        '$dailyLogSheet!A$rowNumber:M$rowNumber',
        valueInputOption: 'USER_ENTERED',
      );
    }, allowInteractive: true);

    // Read back after writing so the app's state is based on the sheet.
    await fetchLogs();
  }

  /// Appends every expense/sale to its own Google Sheet tab, then callers can
  /// refresh from Google Sheets to confirm the write.
  Future<void> appendExpenseRecord(ExpenseSalesLog record) async {
    await _withRetry((api) async {
      final sheet = record.category;
      switch (sheet) {
        case medicalSheet:
          await _append(api, medicalSheet, <Object?>[
            _date(record.date), record.description, '', record.quantity,
            record.unit, record.amount, '', '',
          ]);
          break;
        case feedSheet:
          await _append(api, feedSheet, <Object?>[
            _date(record.date), record.description, '', record.quantity,
            '', record.amount, '', '',
          ]);
          break;
        case gritSheet:
          await _append(api, gritSheet, <Object?>[
            _date(record.date), record.description, '', record.quantity,
            record.amount, '',
          ]);
          break;
        case otherExpensesSheet:
          await _append(api, otherExpensesSheet, <Object?>[
            _date(record.date), record.description, record.description,
            record.quantity, record.amount, '',
          ]);
          break;
        case eggSalesSheet:
          await _append(api, eggSalesSheet, <Object?>[
            _date(record.date), '', record.quantity, 30, '', '',
            record.amount, '', '', '',
          ]);
          break;
        default:
          throw Exception('Unsupported expense category: $sheet');
      }
    }, allowInteractive: true);

    await fetchExpenseRecords();
  }

  Future<void> _append(
    sheets.SheetsApi api,
    String sheetName,
    List<Object?> row,
  ) async {
    await api.spreadsheets.values.append(
      sheets.ValueRange(values: <List<Object?>>[row]),
      spreadsheetId,
      '$sheetName!A:Z',
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
    );
  }

  ExpenseSalesLog? _mapExpenseRow(String sheet, List<Object?> row) {
    final date = _parseDate(row.isNotEmpty ? row[0] : null);
    if (date == null) return null;

    double number(int index) {
      if (index >= row.length) return 0;
      return double.tryParse(row[index].toString()) ?? 0;
    }

    switch (sheet) {
      case medicalSheet:
        return ExpenseSalesLog(
          date: date, category: sheet,
          description: row.length > 1 ? row[1].toString() : '',
          amount: number(5), unit: row.length > 4 ? row[4].toString() : '',
          quantity: number(3),
        );
      case feedSheet:
        return ExpenseSalesLog(
          date: date, category: sheet,
          description: row.length > 1 ? row[1].toString() : '',
          amount: number(5), unit: 'bag', quantity: number(3),
        );
      case gritSheet:
        return ExpenseSalesLog(
          date: date, category: sheet,
          description: row.length > 1 ? row[1].toString() : '',
          amount: number(4), unit: 'kg', quantity: number(3),
        );
      case otherExpensesSheet:
        return ExpenseSalesLog(
          date: date, category: sheet,
          description: row.length > 2 ? row[2].toString() : '',
          amount: number(4), unit: 'unit', quantity: number(3),
        );
      case eggSalesSheet:
        return ExpenseSalesLog(
          date: date, category: sheet,
          description: row.length > 1 ? row[1].toString() : '',
          amount: number(6), unit: 'tray', quantity: number(2),
        );
      default:
        return null;
    }
  }

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
