import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:roipayroll/models/payroll_transaction_model.dart';
import 'package:roipayroll/models/zoho_sync_config_model.dart';
import 'package:roipayroll/services/zoho_oauth_service.dart';

class ZohoBooksService {
  static const Duration _tokenRefreshBuffer = Duration(minutes: 5);
  static const Map<String, String> _defaultAccountMapping = <String, String>{};

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
    this.baseUrl = ZohoSyncConfig.defaultBaseUrl,
    Map<String, String>? accountMapping,
    http.Client? httpClient,
    ZohoOAuthService? oauthService,
    this.onTokenRefreshed,
  }) : _authToken = authToken,
       _tokenExpiresAt = tokenExpiresAt,
       accountMapping = {..._defaultAccountMapping, ...?accountMapping},
       _httpClient = httpClient ?? http.Client(),
       _oauthService = oauthService ?? ZohoOAuthService();

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
      final journalLines = <Map<String, dynamic>>[];

      final debitGroups = _groupAmounts(
        transactions,
        selector: (transaction) => transaction.debitAccount,
      );
      for (final entry in debitGroups.entries) {
        journalLines.add({
          'account_id': _getZohoAccountId(entry.key),
          'debit_amount': _round2(entry.value),
          'description': 'Payroll debit - ${entry.key}',
        });
      }

      final creditGroups = _groupAmounts(
        transactions,
        selector: (transaction) => transaction.creditAccount,
      );
      for (final entry in creditGroups.entries) {
        journalLines.add({
          'account_id': _getZohoAccountId(entry.key),
          'credit_amount': _round2(entry.value),
          'description': 'Payroll credit - ${entry.key}',
        });
      }

      final payload = {
        'journal_date': _formatIsoDate(journalDate),
        'reference_number': referenceNumber,
        'notes': notes,
        'line_items': journalLines,
      };

      final response = await _sendAuthorizedRequest(
        (token) => _httpClient.post(
          _buildUri('/journals'),
          headers: _jsonHeaders(token),
          body: jsonEncode(payload),
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        return ZohoJournalEntryResponse(
          success: false,
          error:
              'Failed to create journal entry: ${response.statusCode} - ${response.body}',
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

  Uri _buildUri(String path, {bool includeOrganizationId = true}) {
    final baseUri = Uri.parse(baseUrl);
    final resolved = baseUri.resolve(
      path.startsWith('/') ? path.substring(1) : path,
    );
    final queryParameters = <String, String>{
      ...resolved.queryParameters,
      if (includeOrganizationId) 'organization_id': organizationId,
    };

    return resolved.replace(queryParameters: queryParameters);
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
        'Missing Zoho account mapping for account code $normalized.',
        details:
            'Update the Zoho Books account mapping before retrying the sync.',
      );
    }
    return mapped;
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
