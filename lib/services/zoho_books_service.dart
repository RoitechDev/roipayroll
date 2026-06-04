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
      // ── FIX 1: validate account mapping BEFORE building any lines so we
      //    surface a clear error rather than letting Zoho return an opaque 400.
      final debitGroups = _groupAmounts(
        transactions,
        selector: (t) => t.debitAccount,
      );
      final creditGroups = _groupAmounts(
        transactions,
        selector: (t) => t.creditAccount,
      );

      // Validate every account code is mapped before hitting the network.
      for (final code in {...debitGroups.keys, ...creditGroups.keys}) {
        _getZohoAccountId(code); // throws ZohoBooksException on miss
      }

      // ── FIX 2: Zoho requires each line_item to have EITHER debit_amount OR
      //    credit_amount — never both and never 0.  Also: amounts must be > 0.
      //    The previous code emitted both keys on the same object which Zoho
      //    rejects with 400.
      final journalLines = <Map<String, dynamic>>[];

      for (final entry in debitGroups.entries) {
        final amount = _round2(entry.value);
        if (amount <= 0) continue; // Zoho rejects zero-amount lines
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

      // ── FIX 3: Zoho Books journal_date must be in yyyy-MM-dd format.
      //    (Was already correct, but kept explicit here for clarity.)
      //
      // ── FIX 4: reference_number must be ≤ 100 chars in Zoho.
      //    Truncate defensively so long run IDs never cause a 400.
      final safeRef = referenceNumber.length > 100
          ? referenceNumber.substring(0, 100)
          : referenceNumber;

      // ── FIX 5: journal_type is required by Zoho Books API (defaults to
      //    "both" which covers standard payroll double-entry).
      final payload = <String, dynamic>{
        'journal_date': _formatIsoDate(journalDate),
        'reference_number': safeRef,
        'notes': notes,
        'journal_type': 'both', // ← required field the original omitted
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
        // Surface Zoho's own error message so it appears in the UI and logs.
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
              'Zoho Books rejected the journal (HTTP ${response.statusCode}): $zohoMessage',
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
    if (_tokenExpiresAt == null) {
      return;
    }

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
          'Zoho access token has expired and no refresh token is configured. Please reconnect Zoho Books.',
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
    if (response.statusCode == 401) {
      return true;
    }

    final body = response.body.toLowerCase();
    return body.contains('invalid_oauthtoken') ||
        body.contains('token expired') ||
        body.contains('invalid oauth token');
  }

  Map<String, String> _authHeaders(String token) {
    return {'Authorization': 'Zoho-oauthtoken $token'};
  }

  Map<String, String> _jsonHeaders(String token) {
    return {..._authHeaders(token), 'Content-Type': 'application/json'};
  }

  // ── FIXED: uses string concatenation instead of Uri.resolve()
  // Uri.resolve() was stripping path segments from the base URL.
  Uri _buildUri(String path, {bool includeOrganizationId = true}) {
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final fullUrl = '$base$cleanPath';
    final uri = Uri.parse(fullUrl);
    final queryParameters = <String, String>{
      ...uri.queryParameters,
      if (includeOrganizationId) 'organization_id': organizationId,
    };
    return uri.replace(queryParameters: queryParameters);
  }

  Map<String, double> _groupAmounts(
    List<PayrollTransaction> transactions, {
    required String Function(PayrollTransaction transaction) selector,
  }) {
    final groups = <String, double>{};
    for (final transaction in transactions) {
      final key = selector(transaction).trim();
      if (key.isEmpty) {
        continue;
      }
      groups[key] = (groups[key] ?? 0.0) + transaction.amountBase;
    }
    return groups;
  }

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

  /// Build a concise per-line description that fits Zoho's 255-char limit.
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

    // Use the first transaction's own description; it's already human-readable.
    final base = matching.first.description;
    final suffix = matching.length > 1 ? ' (+${matching.length - 1} more)' : '';
    final full = '$base$suffix';
    // Zoho caps descriptions at 255 characters.
    return full.length > 255 ? full.substring(0, 252) + '...' : full;
  }

  String _formatIsoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  double _round2(double value) {
    return double.parse(value.toStringAsFixed(2));
  }
}

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
