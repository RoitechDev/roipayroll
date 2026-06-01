class ImportResult {
  final int total;
  int successful;
  int failed;
  final List<String> errors;

  ImportResult({
    required this.total,
    this.successful = 0,
    this.failed = 0,
    List<String>? errors,
  }) : errors = errors ?? <String>[];
}
