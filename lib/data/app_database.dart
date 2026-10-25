import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as legacy;
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;
import 'clinic_repository.dart';
import 'crypto_box.dart';
import 'legacy_migration.dart';
import 'schema.dart';
import 'upgrade_v4.dart';
import 'workspace_repository.dart';

class NeedsConfiguration implements Exception {
  final bool hasLegacy;
  const NeedsConfiguration(this.hasLegacy);
}

class AppDatabase {
  static const secure = FlutterSecureStorage();
  static Future<ClinicRepository> open({MigrationOptions? options}) async {
    final dir = await getApplicationSupportDirectory();
    final oldFile = File('${dir.path}/clinic.db'),
        file = File('${dir.path}/clinic-v020.db');
    final hasOld = await oldFile.exists(), hasNew = await file.exists();
    final oldKey = hasOld ? await secure.read(key: 'vault-key-v1') : null;
    if (hasOld && oldKey == null && !hasNew) {
      throw StateError(
        'مفتاح البيانات السابقة غير موجود. لم يتم تعديل ملفاتك.',
      );
    }
    if (!hasNew && options == null) throw NeedsConfiguration(hasOld);
    var dbKey = await secure.read(key: 'clinic-v020-db-key');
    var gcmKey = await secure.read(key: 'clinic-v020-gcm-key');
    if (hasNew && (dbKey == null || gcmKey == null)) {
      throw StateError(
        'مفتاح قاعدة البيانات غير موجود؛ لن يُنشأ بديل فوق البيانات الحالية.',
      );
    }
    if (dbKey == null) {
      dbKey = base64Encode(
        await (await AesGcm.with256bits().newSecretKey()).extractBytes(),
      );
      await secure.write(key: 'clinic-v020-db-key', value: dbKey);
    }
    if (gcmKey == null) {
      gcmKey = base64Encode(
        await (await AesGcm.with256bits().newSecretKey()).extractBytes(),
      );
      await secure.write(key: 'clinic-v020-gcm-key', value: gcmKey);
    }
    final db = await cipher.openDatabase(
      file.path,
      password: dbKey,
      version: ClinicSchema.version,
      onConfigure: (d) async {
        final encrypted = await d.rawQuery('PRAGMA cipher_version');
        if (encrypted.isEmpty) {
          throw StateError('SQLCipher unavailable; refusing plaintext storage');
        }
        await d.execute('PRAGMA foreign_keys=ON');
        await d.rawQuery('PRAGMA journal_mode=WAL');
        await d.rawQuery('PRAGMA busy_timeout=5000');
      },
      onCreate: (d, v) => ClinicSchema.create(d),
      onUpgrade: (d, old, next) async {
        if (old < 4) await UpgradeV4.run(d);
      },
    );
    final repo = ClinicRepository(
      db,
      CryptoBox(SecretKey(base64Decode(gcmKey))),
    );
    try {
      if (await repo.meta('migration_complete') != '1') {
        if (options == null) throw NeedsConfiguration(hasOld);
        if (hasOld) {
          if (oldKey == null) {
            throw StateError(
              'مفتاح الإصدار السابق غير موجود؛ لم تتغير البيانات',
            );
          }
          final old = await legacy.openDatabase(
            oldFile.path,
            readOnly: true,
            singleInstance: false,
          );
          try {
            await LegacyMigration(
              repo,
            ).run(old, CryptoBox(SecretKey(base64Decode(oldKey))), options);
          } finally {
            await old.close();
          }
        } else {
          if (!RegExp(r'^[A-Z]{3}$').hasMatch(options.currency) ||
              options.minorDigits < 0 ||
              options.minorDigits > 6) {
            throw FormatException('عملة أو دقة غير صالحة');
          }
          await db.transaction((t) async {
            for (final e in {
              'currency': options.currency,
              'minor_digits': '${options.minorDigits}',
              'migration_complete': '1',
            }.entries) {
              await t.insert('app_meta', {
                'meta_id': repo.id(),
                'key': e.key,
                'value': e.value,
              });
            }
          });
        }
      }
      await repo.seedMaterials();
      await WorkspaceRepository(repo).seed();
      if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty ||
          (await db.rawQuery('PRAGMA quick_check')).single.values.single !=
              'ok') {
        throw StateError('Database integrity check failed');
      }
      return repo;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }
}
