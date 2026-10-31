import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as native;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Desktop platforms and `flutter test` use the FFI SQLite driver; Android and
/// iOS use the regular sqflite plugin that ships with the platform.
bool get _useFfi =>
    !kIsWeb &&
    (Platform.isWindows ||
        Platform.isLinux ||
        Platform.isMacOS ||
        Platform.environment.containsKey('FLUTTER_TEST'));

/// Opens (creating if needed) an app database file with the right driver.
Future<Database> openAppDatabase(
  String name, {
  int version = 1,
  OnDatabaseConfigureFn? onConfigure,
  OnDatabaseCreateFn? onCreate,
}) async {
  final DatabaseFactory factory;
  if (_useFfi) {
    sqfliteFfiInit();
    factory = databaseFactoryFfi;
  } else {
    factory = native.databaseFactory;
  }
  final dir = await factory.getDatabasesPath();
  return factory.openDatabase(
    p.join(dir, name),
    options: OpenDatabaseOptions(
      version: version,
      onConfigure: onConfigure,
      onCreate: onCreate,
    ),
  );
}
