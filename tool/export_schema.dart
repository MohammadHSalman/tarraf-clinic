import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tarraf_clinic/data/schema.dart';

Future<void> main() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      singleInstance: false,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys=ON'),
      version: ClinicSchema.version,
      onCreate: (d, v) => ClinicSchema.create(d),
    ),
  );
  final rows = await db.rawQuery(
    "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY CASE type WHEN 'table' THEN 0 WHEN 'index' THEN 1 ELSE 2 END,name",
  );
  await File('docs/schema.sql').writeAsString(
    'PRAGMA foreign_keys=ON;\nBEGIN;\n${rows.map((r) => '${r['sql']};').join('\n\n')}\nCOMMIT;\n',
  );
  await db.close();
}
