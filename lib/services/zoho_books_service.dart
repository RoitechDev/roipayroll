import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:roipayroll/models/payroll_transaction_model.dart';
import 'package:roipayroll/services/zoho_oauth_service.dart';

class ZohoBooksService {
  static const Duration _tokenRefreshBuffer = Duration(minutes: 5);
  static const Map<String, String> _defaultAccountMapping = <String, String>{};
  static const String _proxyBaseUrl = String.fromEnvironment(
    'ROI_ZOHO_PROXY_URL',
    defaultValue: 'http://localhost:3000',
  );
  static const String _proxyBooksBaseUrl = '$_proxyBaseUrl/zoho/books';
  static const String _directZohoBooksBaseUrl =
      'https://www.zohoapis.com/books/v3';

  final String organizationId;
  String _authToken;
  final String? refreshToken;
  DateTime? _tokenExpiresAt;
  final String baseUrl;
  final Map<String, String> accountMapping;
  final http.Client _httpClient;
  final ZohoOAuthService _oauthService;
  final Future<void> Function(String newToken, DateTime expiresAt)?
  onTokenRefreshed;

  ZohoBooksService({
    required this.organizationId,
    required String authToken,
    this.refreshToken,
    DateTime? tokenExpiresAt,
    String? baseUrl,
    Map<String, String>? accountMapping,
    http.Client? httpClient,
    ZohoOAuthService? oauthService,
    this.onTokenRefreshed,
  }) : _authToken = authToken,
       _tokenExpiresAt = tokenExpiresAt,
       baseUrl = _resolveBaseUrl(baseUrl),
       accountMapping = {..._defaultAccountMapping, ...?accountMapping},
       _httpClient = httpClient ?? http.Client(),
       _oauthService = oauthService ?? ZohoOAuthService();

  static String _resolveBaseUrl(String? baseUrl) {
    final normalized = baseUrl?.trim();
    if (normalized == null ||
        normalized.isEmpty ||
        normalized == _directZohoBooksBaseUrl) {
      return _proxyBooksBaseUrl;
    }
    // If the caller saved the bare proxy root (without /zoho/books), append it.
    if (normalized == _proxyBaseUrl || normalized == '$_proxyBaseUrl/') {
      return _proxyBooksBaseUrl;
    }
    return normalized;
  }

  Future<ZohoJournalEntryResponse> createJournalEntry({
    required String referenceNumber,
    required DateTime journalDate,
    required List<PayrollTransaction> transactions,
    required String notes,
  }) async {
    if (transactions.isEmpty) {
      return const ZohoJournalEntryResponse(
        success: false,
        error: 'No payroll transactions provided.',
      );
    }

    try {
      // Group raw amounts by account code for each side of the journal.
      final debitGroups = _groupAmounts(
        transactions,
        selector: (t) => t.debitAccount,
      );
      final creditGroups = _groupAmounts(
        transactions,
        selector: (t) => t.creditAccount,
      );

      // ── FIX: Net out accounts that appear on both sides.
      //
      // Zoho returns {"code":4,"message":"Invalid value passed for Amount"}
      // when the same account_id appears as both a debit line and a credit
      // line in the same journal. This happens legitimately for Employee
      // Payable (2100), which is debited by deduction entries (PAYE, pension,
      // NHF) and credited by the salary accrual entry in the same run.
      //
      // Solution: compute the net position for every account that appears on
      // both sides and emit a single line in the direction of the net. Accounts
      // that appear on only one side are unchanged.
      final allCodes = {...debitGroups.keys, ...creditGroups.keys};
      for (final code in allCodes) {
        final debit = debitGroups[code] ?? 0.0;
        final credit = creditGroups[code] ?? 0.0;
        if (debit > 0 && credit > 0) {
          final net = debit - credit;
          if (net > 0) {
            // Net debit position — keep as debit, remove from credits.
            debitGroups[code] = net;
            creditGroups.remove(code);
          } else if (net < 0) {
            // Net credit position — keep as credit, remove from debits.
            creditGroups[code] = -net;
            debitGroups.remove(code);
          } else {
            // Perfectly balanced — net is zero, drop both sides entirely.
            debitGroups.remove(code);
            creditGroups.remove(code);
          }
        }
      }

      // Validate every remaining account code is mapped before hitting the
      // network, so we surface a clear error instead of an opaque Zoho 400.
      for (final code in {...debitGroups.keys, ...creditGroups.keys}) {
        _getZohoAccountId(code); // throws ZohoBooksException on miss
      }

      // Build line items. Each line has EITHER debit_amount OR credit_amount —
      // never both, never zero. Zoho is strict about this.
      final journalLines = <Map<String, dynamic>>[];

      for (final entry in debitGroups.entries) {
        final amount = _round2(entry.value);
        if (amount <= 0) continue;
        journalLines.add({
          'account_id': _getZohoAccountId(entry.key),
          'debit_amount': amount,
          'description': _lineDescription(
            entry.key,
            transactions,
            isDebit: true,
          ),
        });
      }

      for (final entry in creditGroups.entries) {
        final amount = _round2(entry.value);
        if (amount <= 0) continue;
        journalLines.add({
          'account_id': _getZohoAccountId(entry.key),
          'credit_amount': amount,
          'description': _lineDescription(
            entry.key,
            transactions,
            isDebit: false,
          ),
        });
      }

      if (journalLines.isEmpty) {
        return const ZohoJournalEntryResponse(
          success: false,
          error: 'All transaction amounts are zero — nothing to post to Zoho.',
        );
      }

      // Truncate reference_number to Zoho's 100-char limit.
      final safeRef = referenceNumber.length > 100
          ? referenceNumber.substring(0, 100)
          : referenceNumber;

      final payload = <String, dynamic>{
        'journal_date': _formatIsoDate(journalDate),
        'reference_number': safeRef,
        'notes': notes,
        'journal_type': 'both',
        'line_items': journalLines,
      };

      debugPrint('[ZohoBooks] POST /journals payload: ${jsonEncode(payload)}');

      final response = await _sendAuthorizedRequest(
        (token) => _httpClient.post(
          _buildUri('/journals'),
          headers: _jsonHeaders(token),
          body: jsonEncode(payload),
        ),
      );

      debugPrint(
        '[ZohoBooks] /journals response ${response.statusCode}: ${response.body}',
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        String zohoMessage = response.body;
        try {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          zohoMessage =
              (decoded['message'] ?? decoded['error'] ?? response.body)
                  .toString();
        } catch (_) {}
        return ZohoJournalEntryResponse(
          success: false,
          error:
              'Zoho Books rejected the journal '
              '(HTTP ${response.statusCode}): $zohoMessage',
        );
      }

      final data = jsonDecode(response.body);
      final journal = data is Map<String, dynamic> ? data['journal'] : null;
      final journalMap = journal is Map<String, dynamic>
          ? journal
          : const <String, dynamic>{};

      return ZohoJournalEntryResponse(
        success: true,
        journalId: journalMap['journal_id']?.toString(),
        journalNumber: journalMap['journal_number']?.toString(),
        data: data is Map<String, dynamic> ? data : null,
      );
    } on ZohoBooksException {
      rethrow;
    } catch (error) {
      debugPrint('Zoho Books createJournalEntry error: $error');
      return ZohoJournalEntryResponse(success: false, error: error.toString());
    }
  }

  Future<ZohoTestConnectionResponse> testConnection() async {
    try {
      final response = await _sendAuthorizedRequest(
        (token) => _httpClient.get(
          _buildUri(
            '/organizations/$organizationId',
            includeOrganizationId: false,
          ),
          headers: _authHeaders(token),
        ),
      );

      if (response.statusCode != 200) {
        return ZohoTestConnectionResponse(
          success: false,
          message:
              'Connection failed: ${response.statusCode} - ${response.body}',
        );
      }

      final data = jsonDecode(response.body);
      final organization =
          data is Map<String, dynamic> &&
              data['organization'] is Map<String, dynamic>
          ? data['organization'] as Map<String, dynamic>
          : const <String, dynamic>{};

      return ZohoTestConnectionResponse(
        success: true,
        organizationName: organization['name']?.toString(),
        message: 'Successfully connected to Zoho Books.',
      );
    } catch (error) {
      debugPrint('Zoho Books testConnection error: $error');
      return ZohoTestConnectionResponse(
        success: false,
        message: error.toString(),
      );
    }
  }

  Future<http.Response> _sendAuthorizedRequest(
    Future<http.Response> Function(String token) send,
  ) async {
    await _ensureValidToken();

    var response = await send(_authToken);
    if (_isAuthenticationFailure(response) &&
        (refreshToken ?? '').trim().isNotEmpty) {
      await _refreshToken(force: true);
      response = await send(_authToken);
    }

    return response;
  }

  Future<void> _ensureValidToken() async {
    if (_tokenExpiresAt == null) return;
    final refreshAt = _tokenExpiresAt!.subtract(_tokenRefreshBuffer);
    if (DateTime.now().isAfter(refreshAt)) {
      await _refreshToken();
    }
  }

  Future<void> _refreshToken({bool force = false}) async {
    final normalizedRefreshToken = refreshToken?.trim() ?? '';
    if (normalizedRefreshToken.isEmpty) {
      if (force ||
          (_tokenExpiresAt != null &&
              DateTime.now().isAfter(_tokenExpiresAt!))) {
        throw const ZohoBooksException(
          'Zoho access token has expired and no refresh token is configured. '
          'Please reconnect Zoho Books.',
        );
      }
      return;
    }

    try {
      final tokenResponse = await _oauthService.refreshAccessToken(
        normalizedRefreshToken,
      );
      _authToken = tokenResponse.accessToken;
      _tokenExpiresAt = tokenResponse.expiresAt;

      if (onTokenRefreshed != null) {
        await onTokenRefreshed!(_authToken, _tokenExpiresAt!);
      }
    } catch (error) {
      debugPrint('Zoho token refresh failed: $error');
      throw ZohoBooksException(
        'Failed to refresh Zoho authentication token. Please reconnect Zoho Books.',
        details: error.toString(),
      );
    }
  }

  bool _isAuthenticationFailure(http.Response response) {
    if (response.statusCode == 401) return true;
    final body = response.body.toLowerCase();
    return body.contains('invalid_oauthtoken') ||
        body.contains('token expired') ||
        body.contains('invalid oauth token');
  }

  Map<String, String> _authHeaders(String token) => {
    'Authorization': 'Zoho-oauthtoken $token',
  };

  Map<String, String> _jsonHeaders(String token) => {
    ..._authHeaders(token),
    'Content-Type': 'application/json',
  };

  /// Builds the request URI by appending [path] to [baseUrl] and injecting
  /// the organisation_id query parameter. Uses string concatenation instead of
  /// Uri.resolve() to avoid path-segment stripping.
  Uri _buildUri(String path, {bool includeOrganizationId = true}) {
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('$base$cleanPath');
    final queryParameters = <String, String>{
      ...uri.queryParameters,
      if (includeOrganizationId) 'organization_id': organizationId,
    };
    return uri.replace(queryParameters: queryParameters);
  }

  /// Sums [amountBase] for all transactions grouped by the account code
  /// returned by [selector].
  Map<String, double> _groupAmounts(
    List<PayrollTransaction> transactions, {
    required String Function(PayrollTransaction transaction) selector,
  }) {
    final groups = <String, double>{};
    for (final transaction in transactions) {
      final key = selector(transaction).trim();
      if (key.isEmpty) continue;
      groups[key] = (groups[key] ?? 0.0) + transaction.amountBase;
    }
    return groups;
  }

  /// Looks up the Zoho account ID for [accountCode] in the configured mapping.
  /// Throws [ZohoBooksException] if the code is not mapped.
  String _getZohoAccountId(String accountCode) {
    final normalized = accountCode.trim();
    final mapped = accountMapping[normalized]?.trim();
    if (mapped == null || mapped.isEmpty) {
      throw ZohoBooksException(
        'Missing Zoho account mapping for ledger code "$normalized". '
        'Open Payment Operations → Configure Zoho Books and enter the '
        'Zoho account ID for this code.',
        details:
            'Update the Zoho Books account mapping before retrying the sync.',
      );
    }
    return mapped;
  }

  /// Returns a human-readable description for a journal line, capped at
  /// Zoho's 255-character limit.
  String _lineDescription(
    String accountCode,
    List<PayrollTransaction> transactions, {
    required bool isDebit,
  }) {
    final matching = transactions.where((t) {
      return isDebit
          ? t.debitAccount.trim() == accountCode
          : t.creditAccount.trim() == accountCode;
    }).toList();

    if (matching.isEmpty) {
      return isDebit
          ? 'Payroll debit - $accountCode'
          : 'Payroll credit - $accountCode';
    }

    final base = matching.first.description;
    final suffix = matching.length > 1 ? ' (+${matching.length - 1} more)' : '';
    final full = '$base$suffix';
    return full.length > 255 ? '${full.substring(0, 252)}...' : full;
  }

  String _formatIsoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  // Zoho Books rejects fractional amounts for NGN (which has no sub-unit).
  // Round to the nearest whole number before sending any line item amount.
  // Returns a whole-number int so jsonEncode emits 50000, not 50000.0.
  // Zoho Books rejects float-typed amounts for NGN.
  int _round2(double value) => value.round();
}

// ── Response types ────────────────────────────────────────────────────────────

class ZohoJournalEntryResponse {
  final bool success;
  final String? journalId;
  final String? journalNumber;
  final String? error;
  final Map<String, dynamic>? data;

  const ZohoJournalEntryResponse({
    required this.success,
    this.journalId,
    this.journalNumber,
    this.error,
    this.data,
  });
}

class ZohoTestConnectionResponse {
  final bool success;
  final String? organizationName;
  final String message;

  const ZohoTestConnectionResponse({
    required this.success,
    this.organizationName,
    required this.message,
  });
}

class ZohoBooksException implements Exception {
  final String message;
  final String? details;

  const ZohoBooksException(this.message, {this.details});

  @override
  String toString() {
    if (details == null || details!.trim().isEmpty) {
      return 'ZohoBooksException: $message';
    }
    return 'ZohoBooksException: $message\nDetails: $details';
  }
}
