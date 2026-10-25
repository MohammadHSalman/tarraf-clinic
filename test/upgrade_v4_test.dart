import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cryptography/cryptography.dart';
import 'package:tarraf_clinic/data/clinic_repository.dart';
import 'package:tarraf_clinic/data/crypto_box.dart';
import 'package:tarraf_clinic/data/upgrade_v4.dart';
import 'package:tarraf_clinic/data/workspace_repository.dart';
import 'fixtures/schema_v2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('schema 2 to 4 retains all encrypted historical rows and IDs', () async {
    final dir = await Directory.systemTemp.createTemp('tarraf-upgrade-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/old.db';
    var db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys=ON'),
        onCreate: (d, v) => SchemaV2.create(d),
      ),
    );
    var r = ClinicRepository(db, CryptoBox(SecretKey(List.filled(32, 4))));
    const pid = '00000000-0000-4000-8000-000000000001',
        mid = '00000000-0000-4000-8000-000000000002',
        vid = '00000000-0000-4000-8000-000000000003',
        sid = '00000000-0000-4000-8000-000000000004';
    await db.transaction((t) async {
      await t.execute('PRAGMA defer_foreign_keys=ON');
      for (final e in {
        'currency': 'USD',
        'minor_digits': '2',
        'migration_complete': '1',
      }.entries) {
        await t.insert('app_meta', {
          'meta_id': r.id(),
          'key': e.key,
          'value': e.value,
        });
      }
      await t.insert('patients', {
        'patient_id': pid,
        'payload': await r.box.seal({
          'name': 'Old patient',
          'allergies': 'latex',
        }, context: 'patient:$pid'),
      });
      await t.insert('materials', {
        'material_id': mid,
        'current_name': 'Old material',
        'current_version_id': vid,
      });
      await t.insert('material_versions', {
        'version_id': vid,
        'material_id': mid,
        'name': 'Old material',
        'unit': 'Units',
        'unit_cost_minor': 200,
        'currency': 'USD',
        'created_at': '2026-01-01T00:00:00Z',
      });
      await t.insert('sessions', {
        'session_id': sid,
        'patient_id': pid,
        'procedure_name': 'Legacy injection',
        'category': 'Injection',
        'performed_at': '2026-01-05T12:00:00Z',
        'notes': await r.box.seal({'notes': 'old'}, context: 'session:$sid'),
        'created_at': '2026-01-05T12:00:00Z',
        'updated_at': '2026-01-05T12:00:00Z',
      });
      await t.insert('charges', {
        'charge_id': r.id(),
        'session_id': sid,
        'amount_minor': 10000,
        'description': 'fee',
      });
      await t.update(
        'sessions',
        {'status': 'final'},
        where: 'session_id=?',
        whereArgs: [sid],
      );
    });
    final before = <String, List<Map<String, Object?>>>{
      for (final table in SchemaV2.tables) table: await db.query(table),
    };
    await db.close();
    db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys=ON'),
        onUpgrade: (d, o, n) => UpgradeV4.run(d),
      ),
    );
    r = ClinicRepository(db, r.box);
    addTearDown(db.close);
    for (final table in SchemaV2.tables) {
      final after = await db.query(table);
      expect(after.length, before[table]!.length, reason: table);
      for (var i = 0; i < after.length; i++) {
        for (final e in before[table]![i].entries) {
          expect(after[i][e.key], e.value, reason: '$table.${e.key}');
        }
      }
    }
    await WorkspaceRepository(r).seed();
    expect((await r.patients()).single['name'], 'Old patient');
    expect((await r.session(sid))['performed_at'], '2026-01-05T12:00:00Z');
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    expect((await WorkspaceRepository(r).inventory()).single['stock_milli'], 0);
  });
}
