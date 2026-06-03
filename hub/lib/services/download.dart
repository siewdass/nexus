import 'dart:io';

class ModelDownloader {
  static Future<void> download({
    required String url,
    required String destPath,
    required void Function(int received, int total) onProgress,
  }) async {
    final tmpPath = '$destPath.tmp';
    final client = HttpClient()
      ..userAgent = 'nexus_hub/0.1'
      ..connectionTimeout = const Duration(seconds: 30);

    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      final totalLength = response.contentLength;
      final file = File(tmpPath);
      final sink = file.openWrite();

      int received = 0;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          onProgress(received, totalLength);
        }
      } finally {
        await sink.close();
      }

      if (response.statusCode != 200) {
        throw HttpException(
          'Download failed with status ${response.statusCode}',
          uri: Uri.parse(url),
        );
      }

      await file.rename(destPath);
    } finally {
      client.close(force: true);
    }
  }
}
