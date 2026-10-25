import 'dart:convert';
import 'package:sqflite_common/sqlite_api.dart';
import '../domain/money.dart';
import 'clinic_repository.dart';
import 'crypto_box.dart';

class MigrationOptions {
  final String currency;
  final int minorDigits;
  const MigrationOptions(this.currency, this.minorDigits);
}

class LegacyMigration {
  final ClinicRepository repository;
  LegacyMigration(this.repository);

  /// Legacy DB is read-only, never deleted. Destination commit is all-or-nothing.
  Future<void> run(
    Database legacy,
    CryptoBox oldBox,
    MigrationOptions options,
  ) async {
    if (await repository.meta('migration_complete') == '1') return;
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(options.currency) ||
        options.minorDigits < 0 ||
        options.minorDigits > 6) {
      throw FormatException('عملة أو دقة غير صالحة');
    }
    final original = await legacy.query('records');
    final decoded = <String, Map<String, dynamic>>{};
    for (final r in original) {
      final lid = r['id'] as String;
      if (decoded.containsKey(lid)) throw StateError('Duplicate legacy ID');
      decoded[lid] = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(await oldBox.openBytes(r['payload'] as String)))
            as Map,
      );
    }
    final repo = repository,
        ids = <String, String>{
          for (final r in original) r['id'] as String: repository.id(),
        };
    await repo.db.transaction((t) async {
      // A failed earlier migration leaves an empty destination. Never merge silently.
      if ((await t.query('patients', limit: 1)).isNotEmpty) {
        throw StateError('وجهة الترحيل ليست فارغة');
      }
      await t.insert('app_meta', {
        'meta_id': repo.id(),
        'key': 'currency',
        'value': options.currency,
      });
      await t.insert('app_meta', {
        'meta_id': repo.id(),
        'key': 'minor_digits',
        'value': '${options.minorDigits}',
      });
      for (final r in original) {
        final lid = r['id'] as String, aid = repo.id();
        await t.insert('legacy_archive', {
          'archive_id': aid,
          'legacy_id': lid,
          'kind': r['kind'],
          'payload': await repo.box.seal({
            'record': r,
            'decoded': decoded[lid],
          }, context: 'legacy:$aid'),
        });
        await t.insert('migration_links', {
          'link_id': repo.id(),
          'legacy_id': lid,
          'target_id': ids[lid],
          'kind': r['kind'],
        });
      }
      for (final r in original.where((e) => e['kind'] == 'patients')) {
        final pid = ids[r['id']]!;
        await t.insert('patients', {
          'patient_id': pid,
          'payload': await repo.box.seal(
            decoded[r['id']]!,
            context: 'patient:$pid',
          ),
        });
      }
      String parent(Map<String, Object?> r) {
        final p = ids[r['parent']];
        if (p == null ||
            !original.any(
              (e) => e['id'] == r['parent'] && e['kind'] == 'patients',
            )) {
          throw StateError('علاقة مريض مفقودة: ${r['id']}');
        }
        return p;
      }

      final chargeIds = <String, String>{};
      for (final r in original.where((e) => e['kind'] == 'visits')) {
        final data = decoded[r['id']]!, sid = ids[r['id']]!;
        final at = DateTime.parse(
          data['at'] as String,
        ).toUtc().toIso8601String();
        await t.insert('sessions', {
          'session_id': sid,
          'patient_id': parent(r),
          'performed_at': at,
          'status': 'draft',
          'cost_unresolved': 1,
          'notes': await repo.box.seal(data, context: 'session:$sid'),
          'procedure_name': '${data['procedure'] ?? 'إجراء سابق'}',
          'category': '${data['category'] ?? 'سابق'}',
          'diagram': 'face',
          'created_at': at,
          'updated_at': at,
        });
        final cid = repo.id();
        chargeIds[r['id'] as String] = cid;
        await t.insert('charges', {
          'charge_id': cid,
          'session_id': sid,
          'amount_minor': Money.parse(
            '${data['total'] ?? '0'}',
            options.minorDigits,
          ),
          'description': '${data['procedure'] ?? ''}',
        });
        // The old procedure had a material name but no reliable usage quantity/cost.
        if ('${data['material'] ?? ''}'.trim().isNotEmpty) {
          final vid = await repo.materialVersion(
            t,
            name: '${data['material']}',
            unit: 'Unknown',
            cost: 0,
            currency: options.currency,
            known: false,
          );
          final mid = (await t.query(
            'material_versions',
            where: 'version_id=?',
            whereArgs: [vid],
          )).single['material_id'];
          await t.update(
            'materials',
            {'is_archived': 1},
            where: 'material_id=?',
            whereArgs: [mid],
          );
          await t.insert('session_materials', {
            'session_material_id': repo.id(),
            'session_id': sid,
            'material_id': mid,
            'version_id': vid,
            'quantity': 0,
            'approved_cost_minor': null,
          });
        }
        await t.update(
          'sessions',
          {'status': 'legacy'},
          where: 'session_id=?',
          whereArgs: [sid],
        );
      }
      for (final r in original.where((e) => e['kind'] == 'maps')) {
        final data = decoded[r['id']]!, sid = ids[r['id']]!;
        final at = DateTime.parse(
          data['at'] as String,
        ).toUtc().toIso8601String();
        await t.insert('sessions', {
          'session_id': sid,
          'patient_id': parent(r),
          'performed_at': at,
          'status': 'draft',
          'notes': await repo.box.seal({
            'notes': 'خريطة سابقة مستقلة؛ لا يوجد ربط جلسة موثوق في المصدر',
            'original': data,
          }, context: 'session:$sid'),
          'procedure_name': 'خريطة حقن سابقة',
          'category': 'legacy-map',
          'diagram': data['body'] == true ? 'body' : 'face',
          'created_at': at,
          'updated_at': at,
        });
        var ordinal = 0;
        for (final raw in (data['points'] as List? ?? [])) {
          final point = Map<String, dynamic>.from(raw as Map);
          final unit = '${point['unit']}';
          if (!['Units', 'CC'].contains(unit)) {
            throw FormatException('وحدة سابقة غير معروفة');
          }
          // Do not merge free-text historical materials by guessed name similarity.
          final vid = await repo.materialVersion(
            t,
            name: '${point['material']}',
            unit: unit,
            cost: 0,
            currency: options.currency,
            known: false,
          );
          final mid = (await t.query(
            'material_versions',
            where: 'version_id=?',
            whereArgs: [vid],
          )).single['material_id'];
          String? bid;
          if ('${point['lot'] ?? ''}'.trim().isNotEmpty) {
            bid = repo.id();
            await t.insert('material_batches', {
              'batch_id': bid,
              'material_id': mid,
              'lot_number': '${point['lot']}',
            });
          }
          final usage = repo.id(),
              quantity = Money.parse('${point['units']}', 3);
          await t.update(
            'materials',
            {'is_archived': 1},
            where: 'material_id=?',
            whereArgs: [mid],
          );
          await t.insert('session_materials', {
            'session_material_id': usage,
            'session_id': sid,
            'material_id': mid,
            'version_id': vid,
            'batch_id': bid,
            'quantity': quantity,
            'approved_cost_minor': null,
          });
          await t.insert('injection_points', {
            'point_id': repo.id(),
            'session_material_id': usage,
            'x_coord': (point['x'] as num).toDouble(),
            'y_coord': (point['y'] as num).toDouble(),
            'units_or_cc': quantity,
            'ordinal': ++ordinal,
            'created_at': at,
          });
        }
        await t.update(
          'sessions',
          {'status': 'legacy'},
          where: 'session_id=?',
          whereArgs: [sid],
        );
      }
      await t.update('materials', {'is_archived': 1});
      for (final r in original.where((e) => e['kind'] == 'payments')) {
        final data = decoded[r['id']]!,
            pid = ids[r['id']]!,
            amount = Money.parse('${data['amount']}', options.minorDigits);
        if (amount == 0) {
          continue; // Original zero entry remains losslessly archived.
        }
        await t.insert('payments', {
          'payment_id': pid,
          'patient_id': parent(r),
          'amount_minor': amount,
          'paid_at': DateTime.parse(
            data['at'] as String,
          ).toUtc().toIso8601String(),
          'notes': await repo.box.seal(data, context: 'payment:$pid'),
        });
        final cid = chargeIds[data['visitId']];
        if (cid != null) {
          final c = (await t.query(
            'charges',
            where: 'charge_id=?',
            whereArgs: [cid],
          )).single;
          final already =
              (await t.rawQuery(
                    'SELECT COALESCE(SUM(allocated_amount_minor),0) n FROM payment_allocations WHERE charge_id=?',
                    [cid],
                  )).single['n']
                  as int;
          final remaining = (c['amount_minor'] as int) - already;
          final allocation = amount < remaining ? amount : remaining;
          if (allocation > 0) {
            await t.insert('payment_allocations', {
              'allocation_id': repo.id(),
              'payment_id': pid,
              'charge_id': cid,
              'allocated_amount_minor': allocation,
            });
          }
          // Overpayments remain unallocated credit, never disappear or overpay a charge.
        }
      }
      for (final r in original.where(
        (e) => !['patients', 'visits', 'maps', 'payments'].contains(e['kind']),
      )) {
        final doc = ids[r['id']]!,
            data = Map<String, dynamic>.from(decoded[r['id']]!);
        if (data['ar'] != null) {
          /* retained in settings document */
        }
        await t.insert('documents', {
          'document_id': doc,
          'patient_id': r['parent'] == null ? null : parent(r),
          'kind': r['kind'],
          'payload': await repo.box.seal(data, context: 'document:$doc'),
        });
      }
      final count = (await t.rawQuery(
        'SELECT COUNT(*) n FROM legacy_archive',
      )).single['n'];
      if (count != original.length) throw StateError('فشل فحص عدد السجلات');
      if ((await t.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
        throw StateError('فشل فحص العلاقات');
      }
      await repo.audit(t, repo.id(), 'migration.v011.complete', {
        'count': original.length,
        'currency': options.currency,
        'digits': options.minorDigits,
      });
      await t.insert('app_meta', {
        'meta_id': repo.id(),
        'key': 'reminders_need_reschedule',
        'value': '1',
      });
      await t.insert('app_meta', {
        'meta_id': repo.id(),
        'key': 'migration_complete',
        'value': '1',
      });
    });
  }
}
