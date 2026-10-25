import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;
import 'package:sqflite_common/sqlite_api.dart';
import '../data/clinic_repository.dart';
import '../data/crypto_box.dart';
import '../data/schema.dart';
import '../data/app_database.dart';

class BackupService {
  final ClinicRepository repo;
  BackupService(this.repo);
  Future<CryptoBox> derive(String password, List<int> salt) async {
    if (password.length < 12) {
      throw ArgumentError('12 محرفاً على الأقل / At least 12 characters');
    }
    return CryptoBox(
      await Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 600000,
        bits: 256,
      ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt),
    );
  }

  Future<Map<String, dynamic>> portable() async {
    final rows = await repo.db.transaction(
      (t) async => {
        for (final table in ClinicSchema.tables) table: await t.query(table),
      },
    );
    return {
      'schema': ClinicSchema.version,
      'rows': rows,
      'field_key': base64Encode(await repo.box.key.extractBytes()),
    };
  }

  Future<String> encode(String password) async {
    final salt = AesGcm.with256bits().newNonce(),
        box = await derive(password, salt);
    return jsonEncode({
      'format': 'tarraf-v2',
      'salt': base64Encode(salt),
      'data': await box.seal(await portable(), context: 'tarraf-backup-v2'),
    });
  }

  Future<Map<String, dynamic>> decode(String encoded, String password) async {
    final envelope = jsonDecode(encoded) as Map;
    if (envelope['format'] != 'tarraf-v2') {
      throw const FormatException(
        'نسخة 0.2 مطلوبة؛ استخدم الترحيل للبيانات السابقة',
      );
    }
    final salt = base64Decode(envelope['salt'] as String);
    if (salt.length != 12) throw const FormatException('Invalid salt');
    final data = await (await derive(
      password,
      salt,
    )).open(envelope['data'] as String, context: 'tarraf-backup-v2');
    if (![2, 4].contains(data['schema'])) {
      throw const FormatException('Unsupported schema');
    }
    return data;
  }

  Future<File> export(String password) async {
    final encoded = await encode(password), dir = await getTemporaryDirectory();
    return File(
      '${dir.path}/Tarraf-${DateTime.now().millisecondsSinceEpoch}.tarraf',
    ).writeAsString(encoded, flush: true);
  }

  Future<void> restore(File input, String password) async {
    final data = await decode(await input.readAsString(), password);
    final dir = await getApplicationSupportDirectory(),
        master = await AppDatabase.secure.read(key: 'clinic-v020-db-key');
    if (master == null) throw StateError('Missing database key');
    final stageFile = File('${dir.path}/restore-${repo.id()}.db');
    final staged = await sqlcipher.openDatabase(
      stageFile.path,
      password: master,
      version: ClinicSchema.version,
      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys=ON');
      },
      onCreate: (d, v) => ClinicSchema.create(d),
    );
    try {
      await importPortable(staged, data);
      if ((await staged.rawQuery(
            'PRAGMA integrity_check',
          )).single.values.single !=
          'ok') {
        throw StateError('Backup integrity failed');
      }
      await staged.close();
      await repo.db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      await repo.db.close();
      final active = File('${dir.path}/clinic-v020.db');
      await active.copy(
        '${dir.path}/before-restore-${DateTime.now().millisecondsSinceEpoch}.db',
      );
      // Same directory, same key, atomic replacement. Old encrypted copy retained.
      await stageFile.rename(active.path);
    } catch (_) {
      if (staged.isOpen) await staged.close();
      if (await stageFile.exists()) await stageFile.delete();
      rethrow;
    }
  }

  Future<void> importPortable(
    Database staged,
    Map<String, dynamic> data,
  ) async {
    if (![2, 4].contains(data['schema'])) {
      throw const FormatException('Unsupported schema');
    }
    final rows = Map<String, dynamic>.from(data['rows'] as Map),
        old = CryptoBox(SecretKey(base64Decode(data['field_key'] as String)));
    await staged.transaction((t) async {
      await t.execute('PRAGMA defer_foreign_keys=ON');
      final allocationGuard =
          (await t.rawQuery(
                "SELECT sql FROM sqlite_master WHERE type='trigger' AND name='allocation_guard'",
              )).single['sql']
              as String;
      await t.execute('DROP TRIGGER allocation_guard');
      final statuses = <String, String>{};
      for (final table in ClinicSchema.tables) {
        final records = rows[table];
        if (records is! List) {
          if (data['schema'] == 2 &&
              [
                'material_inventory',
                'stock_movements',
                'procedures',
              ].contains(table)) {
            continue;
          }
          throw FormatException('Missing table $table');
        }
        for (final raw in records) {
          final r = Map<String, Object?>.from(raw as Map);
          String? field, context;
          switch (table) {
            case 'patients':
              field = 'payload';
              context = 'patient:${r['patient_id']}';
            case 'sessions':
              field = 'notes';
              context = 'session:${r['session_id']}';
              statuses[r['session_id'] as String] = r['status'] as String;
              r['status'] = 'draft';
            case 'payments':
              field = 'notes';
              context = 'payment:${r['payment_id']}';
            case 'documents':
              field = 'payload';
              context = 'document:${r['document_id']}';
            case 'legacy_archive':
              field = 'payload';
              context = 'legacy:${r['archive_id']}';
            case 'audit_events':
              field = 'payload';
              context = 'audit:${r['event_id']}';
          }
          if (field != null) {
            r[field] = await repo.box.sealBytes(
              await old.openBytes(r[field] as String, context: context!),
              context: context,
            );
          }
          // Allocations require approved session status. All point/charge rows
          // have been loaded before payments/allocations in schema table order.
          if (table == 'payments') {
            for (final e in statuses.entries) {
              await t.update(
                'sessions',
                {'status': e.value},
                where: 'session_id=?',
                whereArgs: [e.key],
              );
            }
            statuses.clear();
          }
          await t.insert(table, r);
        }
      }
      for (final e in statuses.entries) {
        await t.update(
          'sessions',
          {'status': e.value},
          where: 'session_id=?',
          whereArgs: [e.key],
        );
      }
      if ((await t.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
        throw StateError('Invalid relationships');
      }
      // Verify all immutable totals, not only table syntax.
      final mismatch = await t.rawQuery(
        '''SELECT m.session_material_id FROM session_materials m JOIN sessions s ON s.session_id=m.session_id
          WHERE s.status<>'legacy' AND m.quantity<>COALESCE((SELECT SUM(units_or_cc) FROM injection_points p WHERE p.session_material_id=m.session_material_id),0)''',
      );
      if (mismatch.isNotEmpty) throw StateError('Invalid usage totals');
      if (await t.update(
            'app_meta',
            {'value': '1'},
            where: 'key=?',
            whereArgs: ['reminders_need_reschedule'],
          ) ==
          0) {
        await t.insert('app_meta', {
          'meta_id': repo.id(),
          'key': 'reminders_need_reschedule',
          'value': '1',
        });
      }
      final violations = await t.rawQuery("""
          SELECT a.allocation_id FROM payment_allocations a JOIN payments p ON p.payment_id=a.payment_id
          JOIN charges c ON c.charge_id=a.charge_id JOIN sessions s ON s.session_id=c.session_id
          WHERE p.patient_id<>s.patient_id OR (p.voided_at IS NULL AND s.status NOT IN('final','legacy'))
          UNION ALL SELECT p.payment_id FROM payments p WHERE
          (SELECT COALESCE(SUM(allocated_amount_minor),0) FROM payment_allocations a WHERE a.payment_id=p.payment_id)>p.amount_minor
          UNION ALL SELECT c.charge_id FROM charges c WHERE
          (SELECT COALESCE(SUM(a.allocated_amount_minor),0) FROM payment_allocations a JOIN payments p ON p.payment_id=a.payment_id
           WHERE a.charge_id=c.charge_id AND p.voided_at IS NULL)>c.amount_minor
        """);
      if (violations.isNotEmpty) {
        throw StateError('Invalid payment allocations');
      }
      await t.execute(allocationGuard);
    });
  }
}
