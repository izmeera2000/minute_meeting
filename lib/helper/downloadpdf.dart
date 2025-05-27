import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

Future<String> downloadPdf(String url, String fileName, {String? subfolder}) async {
  final dir = await getTemporaryDirectory();

  // Handle optional subfolder path
  final fullPath = subfolder != null ? '${dir.path}/$subfolder' : dir.path;
  final folder = Directory(fullPath);

  if (!await folder.exists()) {
    await folder.create(recursive: true); // Create the full folder path
  }

  final filePath = '$fullPath/$fileName';
  final file = File(filePath);

  if (await file.exists()) return filePath;

  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  } else {
    throw Exception('Failed to download PDF (status: ${response.statusCode})');
  }
}
