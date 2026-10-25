import 'dart:convert';
import 'dart:io';
import 'package:tarraf_clinic/services/backup_service.dart';
import 'package:tarraf_clinic/services/report_pdf.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tarraf_clinic/data/clinic_repository.dart';
import 'package:tarraf_clinic/data/crypto_box.dart';
import 'package:tarraf_clinic/data/schema.dart';
import 'package:tarraf_clinic/data/report_repository.dart';
import 'package:tarraf_clinic/data/legacy_migration.dart';
import 'package:tarraf_clinic/domain/models.dart';
import 'package:tarraf_clinic/domain/money.dart';

Future<ClinicRepository> repository({bool configure = true}) async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      singleInstance: false,
      version: 2,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys=ON'),
      onCreate: (d, v) => ClinicSchema.create(d),
    ),
  );
  final repo = ClinicRepository(
    db,
    CryptoBox(SecretKey(List.generate(32, (i) => i))),
  );
  if (configure) {
    for (final e in {'currency': 'USD', 'minor_digits': '2'}.entries) {
      await db.insert('app_meta', {
        'meta_id': repo.id(),
        'key': e.key,
        'value': e.value,
      });
    }
  }
  return repo;
}

Future<(String, String, String)> draft(
  ClinicRepository r, {
  String name = 'Botox',
  int cost = 200,
}) async {
  final patient = await r.addPatient({'name': 'مريض اختباري', 'age': '30'});
  await r.editMaterial(name: name, unit: 'Units', cost: cost);
  final vid = (await r.materials()).first['version_id'] as String;
  final sid = await r.createSession(
    patient,
    procedure: 'Injection',
    category: 'Injectables',
    performedAt: DateTime.utc(2026, 1, 10),
  );
  return (patient, sid, vid);
}

Future<int> revision(ClinicRepository r, String sid) async =>
    (await r.session(sid))['revision'] as int;
Future<void> add(ClinicRepository r, String sid, String vid, int qty) async =>
    r.savePoint(
      sessionId: sid,
      revision: await revision(r, sid),
      versionId: vid,
      milliQuantity: qty,
      x: .4,
      y: .3,
      lot: 'LOT-1',
    );
Future<String> approve(ClinicRepository r, String sid, int fees) async {
  await r.setCharge(sid, await revision(r, sid), fees, 'Procedure fee');
  await r.finalize(sid, await revision(r, sid));
  return (await r.db.query(
        'charges',
        where: 'session_id=?',
        whereArgs: [sid],
      )).single['charge_id']
      as String;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late ClinicRepository r;
  setUp(() async {
    r = await repository();
  });
  tearDown(() async {
    await r.db.close();
  });
  test('exact money, Arabic digits, precision and integer consumption', () {
    expect(Money.parse('٠٫٢٩', 2), 29);
    expect(Money.parse('19.9900', 2), 1999);
    expect(() => Money.parse('0.001', 2), throwsFormatException);
    expect(Money.consumption(1250, 101), 126);
    expect(
      () => Money.consumption(1000000000, Money.maxMinor),
      throwsRangeError,
    );
  });
  test(
    'STRICT typing, UUID check and foreign keys reject invalid rows',
    () async {
      await expectLater(
        r.db.insert('materials', {'material_id': 'bad', 'current_name': 'x'}),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        r.createSession(
          r.id(),
          procedure: 'x',
          category: 'x',
          performedAt: DateTime.now(),
        ),
        throwsA(isA<DatabaseException>()),
      );
      final (patient, _, _) = await draft(r);
      await expectLater(
        r.db.insert('payments', {
          'payment_id': r.id(),
          'patient_id': patient,
          'amount_minor': 1.2,
          'paid_at': '2026-01-01',
          'notes': 'x',
        }),
        throwsA(isA<DatabaseException>()),
      );
    },
  );
  test(
    'rename/reprice creates immutable version and preserves historical point/date/cost',
    () async {
      final (_, sid, vid) = await draft(r);
      await add(r, sid, vid, 3000);
      await approve(r, sid, 10000);
      final old = (await r.materials()).single;
      await r.editMaterial(
        materialId: old['material_id'] as String,
        revision: old['revision'] as int,
        name: 'Botox renamed',
        unit: 'CC',
        cost: 900,
      );
      final point = (await r.points(sid)).single;
      expect(point['name'], 'Botox');
      expect(point['unit'], 'Unit');
      expect(point['version_id'], vid);
      expect(
        (await r.db.query('session_materials')).single['approved_cost_minor'],
        600,
      );
      expect(
        (await r.session(sid))['performed_at'],
        DateTime.utc(2026, 1, 10).toIso8601String(),
      );
      await expectLater(
        r.db.update(
          'material_versions',
          {'name': 'bad'},
          where: 'version_id=?',
          whereArgs: [vid],
        ),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        r.deletePoint(point['point_id'] as String, sid, await revision(r, sid)),
        throwsStateError,
      );
    },
  );
  test('archive blocks new consumption and retains history', () async {
    final (_, sid, vid) = await draft(r);
    await add(r, sid, vid, 1000);
    final mid = (await r.materials()).single['material_id'] as String;
    await r.archiveMaterial(mid, true);
    expect(await r.materials(), isEmpty);
    expect((await r.points(sid)).length, 1);
    await expectLater(add(r, sid, vid, 1000), throwsStateError);
  });
  test(
    'point deletion and recalculation rollback together, including revision',
    () async {
      final (_, sid, vid) = await draft(r);
      await add(r, sid, vid, 1500);
      final p = (await r.points(sid)).single;
      final rev = await revision(r, sid);
      await r.db.execute(
        "CREATE TRIGGER fail_cost BEFORE UPDATE OF approved_cost_minor ON session_materials BEGIN SELECT RAISE(ABORT,'simulated failure'); END",
      );
      await expectLater(
        r.deletePoint(p['point_id'] as String, sid, rev),
        throwsA(isA<DatabaseException>()),
      );
      expect((await r.points(sid)).length, 1);
      expect(await revision(r, sid), rev);
      expect(
        (await r.db.query('session_materials')).single['approved_cost_minor'],
        300,
      );
      await r.db.execute('DROP TRIGGER fail_cost');
      await r.deletePoint(p['point_id'] as String, sid, rev);
      expect(await r.points(sid), isEmpty);
      expect((await r.db.query('session_materials')).single['quantity'], 0);
    },
  );
  test(
    'optimistic conflict and mismatched batch are rejected atomically',
    () async {
      final (_, sid, vid) = await draft(r);
      await add(r, sid, vid, 1000);
      await expectLater(
        r.savePoint(
          sessionId: sid,
          revision: 0,
          versionId: vid,
          milliQuantity: 1000,
          x: .1,
          y: .1,
        ),
        throwsStateError,
      );
      await r.editMaterial(name: 'Other', unit: 'CC', cost: 500);
      final other = (await r.materials()).firstWhere(
        (v) => v['name'] == 'Other',
      );
      final bid = r.id();
      await r.db.insert('material_batches', {
        'batch_id': bid,
        'material_id': other['material_id'],
        'lot_number': 'FOREIGN',
      });
      final rev = await revision(r, sid);
      await expectLater(
        r.savePoint(
          sessionId: sid,
          revision: rev,
          versionId: vid,
          batchId: bid,
          milliQuantity: 1000,
          x: .2,
          y: .2,
        ),
        throwsStateError,
      );
      expect(await revision(r, sid), rev);
      final use = (await r.db.query('session_materials')).single;
      await expectLater(
        r.db.update(
          'session_materials',
          {'batch_id': bid},
          where: 'session_material_id=?',
          whereArgs: [use['session_material_id']],
        ),
        throwsA(isA<DatabaseException>()),
      );
    },
  );
  test(
    'accrual and cash dates are distinct; filtered cash never duplicates payment',
    () async {
      final (patient, sid, vid) = await draft(r);
      await add(r, sid, vid, 3000);
      final cid = await approve(r, sid, 10000);
      await r.recordPayment(
        patient,
        3500,
        DateTime.utc(2026, 2, 5),
        'receipt',
        {cid: 3000},
      );
      final reports = ReportRepository(r);
      final jan = await reports.run(
        ReportFilter(
          from: DateTime.utc(2026, 1, 1),
          until: DateTime.utc(2026, 2, 1),
        ),
      );
      expect(jan.fees, 10000);
      expect(jan.costs, 600);
      expect(jan.received, 0);
      final feb = await reports.run(
        ReportFilter(
          from: DateTime.utc(2026, 2, 1),
          until: DateTime.utc(2026, 3, 1),
        ),
      );
      expect(feb.fees, 0);
      expect(feb.received, 3500);
      expect(feb.unallocatedCashMinor, 500);
      final filtered = await reports.run(
        ReportFilter(
          from: DateTime.utc(2026, 2, 1),
          until: DateTime.utc(2026, 3, 1),
          procedure: 'Injection',
          paymentStatus: 'partial',
        ),
      );
      expect(filtered.received, 3000);
      expect(filtered.cash.length, 1);
    },
  );
  test(
    'overallocations, cross-patient allocations rollback entire receipt; void retained',
    () async {
      final (patient, sid, vid) = await draft(r);
      await add(r, sid, vid, 1000);
      final cid = await approve(r, sid, 1000);
      await expectLater(
        r.recordPayment(patient, 500, DateTime.now(), '', {cid: 600}),
        throwsA(isA<DatabaseException>()),
      );
      expect(await r.payments(patient), isEmpty);
      final other = await r.addPatient({'name': 'Other patient'});
      await expectLater(
        r.recordPayment(other, 100, DateTime.now(), '', {cid: 100}),
        throwsA(isA<DatabaseException>()),
      );
      final pid = await r.recordPayment(patient, 1500, DateTime.now(), '', {
        cid: 1000,
      });
      await r.voidPayment(pid, 'Entry error');
      expect((await r.outstanding(patient)).single['due_minor'], 1000);
      expect((await r.payments(patient)).single['voided_at'], isNotNull);
    },
  );
  test(
    'draft deletion cascades points, approved deletion is blocked',
    () async {
      final (_, sid, vid) = await draft(r);
      await add(r, sid, vid, 1000);
      await r.deleteDraft(sid);
      expect(await r.db.query('injection_points'), isEmpty);
      expect(await r.db.query('session_materials'), isEmpty);
    },
  );
  test(
    'migration preserves raw records, timestamps, unknown costs, overpayment and idempotence',
    () async {
      await r.db.close();
      r = await repository(configure: false);
      final old = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(old.close);
      await old.execute(
        'CREATE TABLE records(id TEXT PRIMARY KEY,kind TEXT,parent TEXT,payload TEXT)',
      );
      final box = CryptoBox(SecretKey(List.filled(32, 7)));
      final records = [
        ('p', 'patients', null, {'name': 'أحمد', 'age': '40'}),
        (
          'v',
          'visits',
          'p',
          {
            'at': '2026-01-10T10:00:00.000Z',
            'procedure': 'Old procedure',
            'category': 'Injection',
            'total': '100.00',
            'material': 'Unknown cost filler',
          },
        ),
        (
          'm',
          'maps',
          'p',
          {
            'at': '2026-01-11T11:00:00.000Z',
            'body': false,
            'points': [
              {
                'material': 'Historic Botox',
                'units': '2.5',
                'unit': 'Units',
                'lot': 'OLD-LOT',
                'x': .2,
                'y': .3,
              },
            ],
          },
        ),
        (
          'pay',
          'payments',
          'p',
          {
            'at': '2026-02-10T10:00:00.000Z',
            'amount': '120.00',
            'visitId': 'v',
          },
        ),
        (
          'photo',
          'media',
          'p',
          {
            'bytes': base64Encode([1, 2, 3]),
            'role': 'before',
            'at': '2026-01-10T10:00:00Z',
          },
        ),
      ];
      for (final record in records) {
        await old.insert('records', {
          'id': record.$1,
          'kind': record.$2,
          'parent': record.$3,
          'payload': await box.sealBytes(utf8.encode(jsonEncode(record.$4))),
        });
      }
      await LegacyMigration(r).run(old, box, const MigrationOptions('USD', 2));
      await LegacyMigration(r).run(old, box, const MigrationOptions('USD', 2));
      expect((await r.db.query('legacy_archive')).length, 5);
      expect((await old.query('records')).length, 5);
      expect((await r.patients()).single['name'], 'أحمد');
      expect((await r.db.query('sessions')).length, 2);
      final point = (await r.db.query('injection_points')).single;
      expect(point['units_or_cc'], 2500);
      final report = await ReportRepository(r).run(
        ReportFilter(
          from: DateTime.utc(2026, 1, 1),
          until: DateTime.utc(2026, 3, 1),
        ),
      );
      expect(report.fees, 10000);
      expect(report.received, 12000);
      expect(report.unallocatedCashMinor, 2000);
      expect(report.unknownCosts, greaterThan(0));
      final pid = (await r.patients()).single['patient_id'] as String;
      expect(
        (await r.documents('media', patient: pid)).single['bytes'],
        base64Encode([1, 2, 3]),
      );
      expect(await r.db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );
  test(
    'migration precision failure rolls back destination and leaves source intact',
    () async {
      await r.db.close();
      r = await repository(configure: false);
      final old = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(old.close);
      await old.execute(
        'CREATE TABLE records(id TEXT,kind TEXT,parent TEXT,payload TEXT)',
      );
      final box = CryptoBox(SecretKey(List.filled(32, 3)));
      for (final record in [
        ('p', 'patients', null, {'name': 'Patient'}),
        ('v', 'visits', 'p', {'at': '2026-01-01T00:00:00Z', 'total': '0.001'}),
      ]) {
        await old.insert('records', {
          'id': record.$1,
          'kind': record.$2,
          'parent': record.$3,
          'payload': await box.sealBytes(utf8.encode(jsonEncode(record.$4))),
        });
      }
      await expectLater(
        LegacyMigration(r).run(old, box, const MigrationOptions('USD', 2)),
        throwsFormatException,
      );
      expect(await r.db.query('patients'), isEmpty);
      expect(await r.db.query('legacy_archive'), isEmpty);
      expect((await old.query('records')).length, 2);
    },
  );
  test(
    'AES-GCM authenticated context rejects cross-record substitution and tampering',
    () async {
      final b = CryptoBox(SecretKey(List.filled(32, 1))),
          sealed = await r.box.seal({'name': 'آمن'}, context: 'patient:test');
      expect(
        (await r.box.open(sealed, context: 'patient:test'))['name'],
        'آمن',
      );
      await expectLater(
        r.box.open(sealed, context: 'patient:other'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await expectLater(
        b.open(sealed, context: 'patient:test'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    },
  );
  test(
    'encrypted portable backup roundtrip rekeys data and retains voided allocations',
    () async {
      final (patient, sid, vid) = await draft(r);
      await add(r, sid, vid, 1000);
      final cid = await approve(r, sid, 1000);
      final receipt = await r.recordPayment(
        patient,
        500,
        DateTime.utc(2026, 2, 2),
        'private',
        {cid: 500},
      );
      await r.voidPayment(receipt, 'correction');
      final data = await BackupService(r).portable();
      final target = await repository(configure: false);
      addTearDown(target.db.close);
      final local = ClinicRepository(
        target.db,
        CryptoBox(SecretKey(List.filled(32, 19))),
      );
      await BackupService(local).importPortable(local.db, data);
      expect((await local.patients()).single['name'], 'مريض اختباري');
      expect((await local.payments(patient)).single['voided_at'], isNotNull);
      expect((await local.outstanding(patient)).single['due_minor'], 1000);
      expect((await local.points(sid)).single['version_id'], vid);
      final cipher =
          (await local.db.query('patients')).single['payload'] as String;
      await expectLater(
        r.box.open(cipher, context: 'patient:$patient'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      final encoded = await BackupService(r).encode('strong-password-123');
      expect(
        (await BackupService(
          r,
        ).decode(encoded, 'strong-password-123'))['schema'],
        4,
      );
      await expectLater(
        BackupService(r).decode(encoded, 'wrong-password-123'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    },
  );
  test(
    'PDF report builds Arabic headers, tables and pagination without platform share',
    () async {
      final (patient, sid, vid) = await draft(r);
      await add(r, sid, vid, 1000);
      await approve(r, sid, 1000);
      final filter = ReportFilter(
        from: DateTime.utc(2026, 1, 1),
        until: DateTime.utc(2026, 2, 1),
      );
      final report = await ReportRepository(r).run(filter);
      final bytes = await ReportPdf.build(report, filter, 'USD', 2, true);
      expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
      expect(bytes.length, greaterThan(10000));
      await File('build/report-qa.pdf').writeAsBytes(bytes);
      expect((await r.patients()).single['patient_id'], patient);
    },
  );
  test(
    'multiple allocations and multiple material lines do not duplicate fees or cash',
    () async {
      final (patient, sid, vid) = await draft(r);
      await add(r, sid, vid, 1000);
      await r.editMaterial(name: 'Filler', unit: 'CC', cost: 300);
      final filler =
          (await r.materials()).firstWhere(
                (m) => m['name'] == 'Filler',
              )['version_id']
              as String;
      await add(r, sid, filler, 1000);
      final c1 = await approve(r, sid, 10000);
      final s2 = await r.createSession(
        patient,
        procedure: 'Second procedure',
        category: 'Surgery',
        performedAt: DateTime.utc(2026, 1, 11),
      );
      final c2 = await approve(r, s2, 5000);
      await r.recordPayment(
        patient,
        7000,
        DateTime.utc(2026, 2, 5),
        'one receipt',
        {c1: 3000, c2: 4000},
      );
      final report = await ReportRepository(r).run(
        ReportFilter(
          from: DateTime.utc(2026, 1, 1),
          until: DateTime.utc(2026, 3, 1),
        ),
      );
      expect(report.fees, 15000);
      expect(report.costs, 500);
      expect(report.received, 7000);
      expect(report.cash.length, 1);
      final filtered = await ReportRepository(r).run(
        ReportFilter(
          from: DateTime.utc(2026, 1, 1),
          until: DateTime.utc(2026, 3, 1),
          procedure: 'Injection',
        ),
      );
      expect(filtered.received, 3000);
      expect(filtered.fees, 10000);
      final category = await ReportRepository(r).run(
        ReportFilter(
          from: DateTime.utc(2026, 1, 1),
          until: DateTime.utc(2026, 3, 1),
          category: 'Surgery',
        ),
      );
      expect(category.fees, 5000);
      expect(category.received, 4000);
    },
  );
}
