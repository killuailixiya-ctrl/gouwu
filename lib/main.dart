import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'db_init.dart' if (dart.library.io) 'db_init_io.dart';
import 'sqflite_init.dart'
    if (dart.library.ffi) 'sqflite_init_ffi.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initSqflite();
  initDatabase();

  FlutterError.onError = (details) {
    debugPrint('[FlutterError] ${details.exception}');
    debugPrint('[FlutterError] stack: ${details.stack}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error');
    debugPrint('[PlatformError] stack: $stack');
    return true;
  };

  runApp(const GouWuApp());
}