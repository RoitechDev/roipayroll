import 'csv_file_helper_stub.dart'
    if (dart.library.html) 'csv_file_helper_web.dart' as impl;

Future<String?> pickCsvText() => impl.pickCsvText();

Future<void> downloadCsvFile({
  required String fileName,
  required String csv,
}) =>
    impl.downloadCsvFile(fileName: fileName, csv: csv);
