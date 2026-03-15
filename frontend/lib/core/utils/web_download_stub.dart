// Stub implementation for non-web platforms
void triggerBrowserDownload(List<int> bytes, String filename, String mimeType) {
  throw UnsupportedError('triggerBrowserDownload is only available on web');
}
