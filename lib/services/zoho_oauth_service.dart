import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ZohoOAuthService {
  // Zoho Client ID - passed via --dart-define at build time.
  static const String _clientId = String.fromEnvironment('ROI_ZOHO_CLIENT_ID');

  // Zoho accounts base URL - override for non-global datacenters.
  static const String _accountsBaseUrl = String.fromEnvironment(
    'ROI_ZOHO_ACCOUNTS_BASE_URL',
    defaultValue: 'https://accounts.zoho.com',
  );

  // Render proxy URL - defaults to localhost:3000 for local development.
  static const String _proxyBaseUrl = String.fromEnvironment(
    'ROI_ZOHO_PROXY_URL',
    defaultValue: 'http://localhost:3000',
  );

  final http.Client _httpClient;

  ZohoOAuthService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  String get _proxyTokenEndpoint => '$_proxyBaseUrl/zoho/token';

  Future<ZohoTokenResponse> exchangeAuthorizationCode({
    required String code,
    required String redirectUri,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse(_proxyTokenEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
        }),
      );

      return _parseProxyResponse(response);
    } catch (error) {
      debugPrint('Zoho OAuth exchange error: $error');
      rethrow;
    }
  }

  String generateAuthorizationUrl({
    required String redirectUri,
    required String scope,
    String? state,
  }) {
    _ensureClientIdConfigured();

    final queryParameters = <String, String>{
      'client_id': _clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'scope': scope,
      'access_type': 'offline',
    };
    if (state != null) {
      queryParameters['state'] = state;
    }

    final uri = Uri.parse(
      '$_accountsBaseUrl/oauth/v2/auth',
    ).replace(queryParameters: queryParameters);

    return uri.toString();
  }

  Future<ZohoTokenResponse> refreshAccessToken(String refreshToken) async {
    try {
      final response = await _httpClient.post(
        Uri.parse(_proxyTokenEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        }),
      );

      return _parseProxyResponse(response);
    } catch (error) {
      debugPrint('Zoho token refresh error: $error');
      rethrow;
    }
  }

  ZohoTokenResponse _parseProxyResponse(http.Response response) {
    Map<String, dynamic>? data;

    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ZohoOAuthException(
        'Invalid response from proxy server.',
        response.body,
      );
    }

    if (response.statusCode != 200) {
      throw ZohoOAuthException(
        data['error']?.toString() ??
            'Token request failed (HTTP ${response.statusCode})',
        data['error_description']?.toString() ??
            data['details']?.toString() ??
            response.body,
      );
    }

    if (data['error'] != null) {
      throw ZohoOAuthException(
        'Zoho error: ${data['error']}',
        data['error_description']?.toString(),
      );
    }

    if (data['access_token'] == null) {
      throw ZohoOAuthException('Response missing access_token.', response.body);
    }

    return ZohoTokenResponse(
      accessToken: data['access_token'].toString(),
      refreshToken: data['refresh_token']?.toString(),
      expiresIn: (data['expires_in'] as num?)?.toInt() ?? 3600,
      tokenType: data['token_type']?.toString(),
    );
  }

  Future<bool> validateToken({
    required String accessToken,
    required String organizationId,
    String baseUrl = 'https://www.zohoapis.com/books/v3',
  }) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/organizations/$organizationId'),
        headers: {'Authorization': 'Zoho-oauthtoken $accessToken'},
      );
      return response.statusCode == 200;
    } catch (error) {
      debugPrint('Zoho token validation error: $error');
      return false;
    }
  }

  void _ensureClientIdConfigured() {
    if (_clientId.trim().isEmpty) {
      throw const ZohoOAuthException(
        'Zoho OAuth client ID is missing. Set ROI_ZOHO_CLIENT_ID before opening the Zoho consent screen.',
      );
    }
  }
}

class ZohoTokenResponse {
  final String accessToken;
  final String? refreshToken;
  final int expiresIn;
  final String? tokenType;

  const ZohoTokenResponse({
    required this.accessToken,
    this.refreshToken,
    required this.expiresIn,
    this.tokenType,
  });

  DateTime get expiresAt => DateTime.now().add(Duration(seconds: expiresIn));
}

class ZohoOAuthException implements Exception {
  final String message;
  final String? details;

  const ZohoOAuthException(this.message, [this.details]);

  @override
  String toString() {
    if (details == null || details!.trim().isEmpty) {
      return 'ZohoOAuthException: $message';
    }
    return 'ZohoOAuthException: $message\nDetails: $details';
  }
}
