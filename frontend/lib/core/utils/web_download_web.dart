import 'dart:convert';
import 'package:web/web.dart' as web;

void triggerBrowserDownload(List<int> bytes, String filename, String mimeType) {
  final base64Data = base64Encode(bytes);
  final dataUrl = 'data:$mimeType;base64,$base64Data';
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = dataUrl;
  anchor.download = filename;
  anchor.click();
}
