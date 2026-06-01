// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

Future<String?> pickCsvText() async {
  final input = html.FileUploadInputElement()
    ..accept = '.csv,text/csv'
    ..multiple = false;
  input.click();

  await input.onChange.first;
  if (input.files == null || input.files!.isEmpty) {
    return null;
  }

  final file = input.files!.first;
  final reader = html.FileReader();
  final completer = Completer<String?>();

  reader.onLoadEnd.listen((_) {
    final result = reader.result;
    if (result is String) {
      completer.complete(result);
      return;
    }
    if (result is List<int>) {
      completer.complete(utf8.decode(result));
      return;
    }
    completer.complete(null);
  });

  reader.readAsText(file);
  return completer.future;
}

Future<void> downloadCsvFile({
  required String fileName,
  required String csv,
}) async {
  final bytes = utf8.encode(csv);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
