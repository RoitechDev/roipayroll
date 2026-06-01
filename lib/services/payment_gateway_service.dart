import 'package:roipayroll/models/payment_batch_model.dart';

abstract class PaymentGatewayService {
  Future<PaymentResult> processPayment({
    required String reference,
    required String accountNumber,
    required String bankCode,
    required double amount,
    required String currency,
    required String narration,
  });

  Future<BatchPaymentResult> processBatchPayment({
    required List<PaymentInstruction> payments,
  });

  Future<PaymentStatusResponse> checkPaymentStatus(String reference);

  Future<List<BankInfo>> getSupportedBanks();
}

class PaymentInstruction {
  final String reference;
  final String accountNumber;
  final String bankCode;
  final double amount;
  final String currency;
  final String narration;
  final Map<String, dynamic>? metadata;

  const PaymentInstruction({
    required this.reference,
    required this.accountNumber,
    required this.bankCode,
    required this.amount,
    required this.currency,
    required this.narration,
    this.metadata,
  });
}

class PaymentResult {
  final bool success;
  final String? reference;
  final String? gatewayReference;
  final String? message;
  final PaymentStatus status;
  final Map<String, dynamic>? data;

  const PaymentResult({
    required this.success,
    required this.status,
    this.reference,
    this.gatewayReference,
    this.message,
    this.data,
  });
}

class BatchPaymentResult {
  final int totalCount;
  final int successCount;
  final int failedCount;
  final List<PaymentResult> results;

  const BatchPaymentResult({
    required this.totalCount,
    required this.successCount,
    required this.failedCount,
    required this.results,
  });
}

class PaymentStatusResponse {
  final PaymentStatus status;
  final String reference;
  final Map<String, dynamic>? data;

  const PaymentStatusResponse({
    required this.status,
    required this.reference,
    this.data,
  });
}

class BankInfo {
  final String code;
  final String name;

  const BankInfo({required this.code, required this.name});
}
