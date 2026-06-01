import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/services/encryption_service.dart';

const Object _zohoConfigUnset = Object();

DateTime _readConfigDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return DateTime.now();
}

DateTime? _readNullableConfigDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

Map<String, String> _readAccountMapping(dynamic value) {
  if (value is! Map) {
    return const <String, String>{};
  }

  return value.map<String, String>((key, entryValue) {
    return MapEntry(key.toString(), entryValue?.toString() ?? '');
  });
}

class ZohoSyncConfig {
  static const String defaultBaseUrl = 'https://www.zohoapis.com/books/v3';
  static const Map<String, String> supportedAccounts = {
    '5100': 'Salary Expense',
    '5110': 'Expense Reimbursement Expense',
    '5120': 'Incentive Expense',
    '2100': 'Employee Payable',
    '2110': 'PAYE Payable',
    '2120': 'Pension Payable',
    '2130': 'NHF Payable',
    '2150': 'Other Deductions Payable',
    '1200': 'Employee Loan Receivable',
    '1210': 'Salary Advance Receivable',
    '1010': 'Bank Account',
  };

  final String organizationId;
  final String authToken;
  final String? refreshToken;
  final DateTime? tokenExpiresAt;
  final String baseUrl;
  final Map<String, String> accountMapping;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastValidatedAt;
  final DateTime? lastSyncedAt;

  const ZohoSyncConfig({
    required this.organizationId,
    required this.authToken,
    this.refreshToken,
    this.tokenExpiresAt,
    this.baseUrl = defaultBaseUrl,
    this.accountMapping = const <String, String>{},
    required this.createdAt,
    required this.updatedAt,
    this.lastValidatedAt,
    this.lastSyncedAt,
  });

  bool get isConfigured =>
      organizationId.trim().isNotEmpty && authToken.trim().isNotEmpty;

  bool get hasValidConfiguration => validateConfiguration() == null;

  bool get isReadyForSync => isConfigured && hasValidConfiguration;

  bool get isTokenExpired {
    if (tokenExpiresAt == null) {
      return false;
    }
    return DateTime.now().isAfter(tokenExpiresAt!);
  }

  bool get canRefreshToken => (refreshToken ?? '').trim().isNotEmpty;

  String get maskedToken {
    final normalized = authToken.trim();
    if (normalized.length <= 8) {
      return normalized.isEmpty ? '' : 'Configured';
    }
    return '${normalized.substring(0, 4)}...${normalized.substring(normalized.length - 4)}';
  }

  String? validateConfiguration() {
    if (organizationId.trim().isEmpty) {
      return 'Organization ID is required.';
    }

    if (authToken.trim().isEmpty) {
      return 'Auth token is required.';
    }

    final normalizedBaseUrl = baseUrl.trim();
    if (normalizedBaseUrl.isEmpty) {
      return 'Base URL is required.';
    }

    final parsedBaseUrl = Uri.tryParse(normalizedBaseUrl);
    if (parsedBaseUrl == null ||
        !parsedBaseUrl.hasScheme ||
        !parsedBaseUrl.hasAuthority) {
      return 'Base URL must be a valid HTTPS endpoint.';
    }

    if (accountMapping.isEmpty) {
      return 'Account mapping is required.';
    }

    for (final entry in supportedAccounts.entries) {
      final mapping = accountMapping[entry.key]?.trim() ?? '';
      if (mapping.isEmpty) {
        return 'Account ${entry.key} (${entry.value}) must be mapped to a Zoho account ID.';
      }
    }

    return null;
  }

  Future<Map<String, dynamic>> toJsonEncrypted() async {
    return {
      'organizationId': organizationId,
      'authToken': await EncryptionService.encrypt(authToken),
      'refreshToken': await EncryptionService.encrypt(refreshToken),
      'tokenExpiresAt': tokenExpiresAt == null
          ? null
          : Timestamp.fromDate(tokenExpiresAt!),
      'baseUrl': baseUrl,
      'accountMapping': accountMapping,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastValidatedAt': lastValidatedAt == null
          ? null
          : Timestamp.fromDate(lastValidatedAt!),
      'lastSyncedAt': lastSyncedAt == null
          ? null
          : Timestamp.fromDate(lastSyncedAt!),
    };
  }

  static Future<ZohoSyncConfig> fromJsonEncrypted(
    Map<String, dynamic> json,
  ) async {
    return ZohoSyncConfig(
      organizationId: (json['organizationId'] ?? '').toString(),
      authToken:
          await EncryptionService.decrypt(json['authToken']?.toString()) ?? '',
      refreshToken: await EncryptionService.decrypt(
        json['refreshToken']?.toString(),
      ),
      tokenExpiresAt: _readNullableConfigDate(json['tokenExpiresAt']),
      baseUrl: (json['baseUrl'] ?? defaultBaseUrl).toString(),
      accountMapping: _readAccountMapping(json['accountMapping']),
      createdAt: _readConfigDate(json['createdAt']),
      updatedAt: _readConfigDate(json['updatedAt']),
      lastValidatedAt: _readNullableConfigDate(json['lastValidatedAt']),
      lastSyncedAt: _readNullableConfigDate(json['lastSyncedAt']),
    );
  }

  factory ZohoSyncConfig.fromJson(Map<String, dynamic> json) {
    return ZohoSyncConfig(
      organizationId: (json['organizationId'] ?? '').toString(),
      authToken: (json['authToken'] ?? '').toString(),
      refreshToken: json['refreshToken']?.toString(),
      tokenExpiresAt: _readNullableConfigDate(json['tokenExpiresAt']),
      baseUrl: (json['baseUrl'] ?? defaultBaseUrl).toString(),
      accountMapping: _readAccountMapping(json['accountMapping']),
      createdAt: _readConfigDate(json['createdAt']),
      updatedAt: _readConfigDate(json['updatedAt']),
      lastValidatedAt: _readNullableConfigDate(json['lastValidatedAt']),
      lastSyncedAt: _readNullableConfigDate(json['lastSyncedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'organizationId': organizationId,
      'authToken': authToken,
      'refreshToken': refreshToken,
      'tokenExpiresAt': tokenExpiresAt == null
          ? null
          : Timestamp.fromDate(tokenExpiresAt!),
      'baseUrl': baseUrl,
      'accountMapping': accountMapping,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastValidatedAt': lastValidatedAt == null
          ? null
          : Timestamp.fromDate(lastValidatedAt!),
      'lastSyncedAt': lastSyncedAt == null
          ? null
          : Timestamp.fromDate(lastSyncedAt!),
    };
  }

  ZohoSyncConfig copyWith({
    String? organizationId,
    String? authToken,
    Object? refreshToken = _zohoConfigUnset,
    Object? tokenExpiresAt = _zohoConfigUnset,
    String? baseUrl,
    Map<String, String>? accountMapping,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? lastValidatedAt = _zohoConfigUnset,
    Object? lastSyncedAt = _zohoConfigUnset,
  }) {
    return ZohoSyncConfig(
      organizationId: organizationId ?? this.organizationId,
      authToken: authToken ?? this.authToken,
      refreshToken: refreshToken == _zohoConfigUnset
          ? this.refreshToken
          : refreshToken as String?,
      tokenExpiresAt: tokenExpiresAt == _zohoConfigUnset
          ? this.tokenExpiresAt
          : tokenExpiresAt as DateTime?,
      baseUrl: baseUrl ?? this.baseUrl,
      accountMapping: accountMapping ?? this.accountMapping,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastValidatedAt: lastValidatedAt == _zohoConfigUnset
          ? this.lastValidatedAt
          : lastValidatedAt as DateTime?,
      lastSyncedAt: lastSyncedAt == _zohoConfigUnset
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
    );
  }
}
