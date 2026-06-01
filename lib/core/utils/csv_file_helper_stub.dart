Future<String?> pickCsvText() async {
  return null;
}

Future<void> downloadCsvFile({
  required String fileName,
  required String csv,
}) async {
  throw UnsupportedError('CSV download is currently supported on web only.');
}
