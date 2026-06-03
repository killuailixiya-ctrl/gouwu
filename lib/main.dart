import 'package:flutter/material.dart';
import 'app.dart';
import 'db_init.dart' if (dart.library.io) 'db_init_io.dart';
import 'sqflite_init.dart'
    if (dart.library.ffi) 'sqflite_init_ffi.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initSqflite();
  initDatabase();
  runApp(const GouWuApp());
}