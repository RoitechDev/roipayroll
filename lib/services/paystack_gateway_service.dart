import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:roipayroll/models/payment_batch_model.dart';
import 'package:roipayroll/services/payment_gateway_service.dart';

/// Security note:
/// Paystack secret keys should be used from trusted backend code.
/// This client-side service is best treated as a temporary integration seam
/// or routed through a secure server-side proxy before production use.
class PaystackGatewayService implements PaymentGatewayService {
  final String secretKey;
  final String baseUrl;
  final http.Client _httpClient;

  PaystackGatewayService({
    required this.secretKey,
    this.baseUrl = 'https://api.paystack.co',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  @override
  Future<PaymentResult> processPayment({
    required String reference,
    required String accountNumber,
    required String bankCode,
    required double amount,
    required String currency,
    required String narration,
  }) async {
    try {
      final recipientResponse = await _httpClient.post(
        Uri.parse('$baseUrl/transferrecipient'),
        headers: _headers(),
        body: jsonEncode({
          'type': 'nuban',
          'name': narration,
          'account_number': accountNumber,
          'bank_code': bankCode,
          'currency': currency,
        }),
      );

      if (!_isSuccessCode(recipientResponse.statusCode)) {
        return PaymentResult(
          success: false,
          status: PaymentStatus.failed,
          reference: reference,
          message: 'Failed to create recipient: ${recipientResponse.body}',
        );
      }

      final recipientData = _parseBody(recipientResponse.body);
      final recipientCode =
          recipientData['data']?['recipient_code']?.toString() ?? '';
      if (recipientCode.isEmpty) {
        return PaymentResult(
          success: false,
          status: PaymentStatus.failed,
          reference: reference,
          message: 'Recipient code missing from Paystack response.',
          data: recipientData,
        );
      }

      final transferResponse = await _httpClient.post(
        Uri.parse('$baseUrl/transfer'),
        headers: _headers(),
        body: jsonEncode({
          'source': 'balance',
          'amount': (amount * 100).round(),
          'recipient': recipientCode,
          'reason': narration,
          'reference': reference,
        }),
      );

      if (!_isSuccessCode(transferResponse.statusCode)) {
        return PaymentResult(
          success: false,
          status: PaymentStatus.failed,
          reference: reference,
          message: 'Transfer failed: ${transferResponse.body}',
        );
      }

      final transferData = _parseBody(transferResponse.body);
      final gatewayStatus = _mapPaystackStatus(
        transferData['data']?['status']?.toString(),
      );
      return PaymentResult(
        success:
            gatewayStatus == PaymentStatus.completed ||
            gatewayStatus == PaymentStatus.processing,
        status: gatewayStatus,
        reference: reference,
        gatewayReference:
            transferData['data']?['transfer_code']?.toString() ??
            transferData['data']?['reference']?.toString(),
        message:
            transferData['message']?.toString() ??
            'Transfer initiated successfully',
        data: transferData['data'] is Map<String, dynamic>
            ? transferData['data'] as Map<String, dynamic>
            : null,
      );
    } catch (error) {
      return PaymentResult(
        success: false,
        status: PaymentStatus.failed,
        reference: reference,
        message: 'Exception: $error',
      );
    }
  }

  @override
  Future<BatchPaymentResult> processBatchPayment({
    required List<PaymentInstruction> payments,
  }) async {
    final results = <PaymentResult>[];
    var successCount = 0;
    var failedCount = 0;

    for (final payment in payments) {
      final result = await processPayment(
        reference: payment.reference,
        accountNumber: payment.accountNumber,
        bankCode: payment.bankCode,
        amount: payment.amount,
        currency: payment.currency,
        narration: payment.narration,
      );
      results.add(result);
      if (result.success) {
        successCount++;
      } else {
        failedCount++;
      }
    }

    return BatchPaymentResult(
      totalCount: payments.length,
      successCount: successCount,
      failedCount: failedCount,
      results: results,
    );
  }

  @override
  Future<PaymentStatusResponse> checkPaymentStatus(String reference) async {
    final response = await _httpClient.get(
      Uri.parse('$baseUrl/transfer/verify/$reference'),
      headers: _authHeaders(),
    );
    final data = _parseBody(response.body);
    return PaymentStatusResponse(
      status: _mapPaystackStatus(data['data']?['status']?.toString()),
      reference: reference,
      data: data['data'] is Map<String, dynamic>
          ? data['data'] as Map<String, dynamic>
          : null,
    );
  }

  @override
  Future<List<BankInfo>> getSupportedBanks() async {
    final response = await _httpClient.get(
      Uri.parse('$baseUrl/bank'),
      headers: _authHeaders(),
    );
    if (!_isSuccessCode(response.statusCode)) {
      throw Exception('Failed to fetch supported banks: ${response.body}');
    }

    final data = _parseBody(response.body);
    final banks = data['data'];
    if (banks is! List) {
      return const <BankInfo>[];
    }

    return banks
        .whereType<Map>()
        .map(
          (bank) => BankInfo(
            code: (bank['code'] ?? '').toString(),
            name: (bank['name'] ?? '').toString(),
          ),
        )
        .where((bank) => bank.code.isNotEmpty && bank.name.isNotEmpty)
        .toList();
  }

  Map<String, String> _headers() {
    return {..._authHeaders(), 'Content-Type': 'application/json'};
  }

  Map<String, String> _authHeaders() {
    return {'Authorization': 'Bearer $secretKey'};
  }

  bool _isSuccessCode(int code) => code == 200 || code == 201;

  Map<String, dynamic> _parseBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{'data': decoded};
  }

  PaymentStatus _mapPaystackStatus(String? paystackStatus) {
    switch ((paystackStatus ?? '').trim().toLowerCase()) {
      case 'success':
      case 'successful':
        return PaymentStatus.completed;
      case 'failed':
      case 'error':
      case 'rejected':
        return PaymentStatus.failed;
      case 'reversed':
        return PaymentStatus.reversed;
      case 'pending':
      case 'otp':
      case 'received':
      case 'processing':
        return PaymentStatus.processing;
      default:
        return PaymentStatus.pending;
    }
  }
}
