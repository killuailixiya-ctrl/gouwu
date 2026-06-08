import 'dart:io';

final mime = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.wasm': 'application/wasm',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

void main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8788);
  print('Serving on http://localhost:${server.port}');
  await for (var request in server) {
    var path = request.uri.path;
    if (path == '/') path = '/index.html';
    final file = File('build/web$path');
    try {
      if (await file.exists()) {
        final ext = path.substring(path.lastIndexOf('.'));
        request.response.headers.contentType = ContentType.parse(mime[ext] ?? 'application/octet-stream');
        request.response.headers.add('Cache-Control', 'no-cache');
        await request.response.addStream(file.openRead());
      } else {
        request.response.statusCode = 404;
      }
    } catch (e) {
      request.response.statusCode = 500;
    }
    await request.response.close();
  }
}