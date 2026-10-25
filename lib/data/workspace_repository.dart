import 'package:sqflite_common/sqlite_api.dart';
import '../domain/models.dart';
import '../domain/fx.dart';
import 'clinic_repository.dart';

class WorkspaceRepository {
  final ClinicRepository r;
  WorkspaceRepository(this.r);
  Future<Fx> fx() async => Fx(
    await r.currency,
    await r.digits,
    await r.meta('base_currency') ?? await r.currency,
    int.parse(await r.meta('fx_rate_micros') ?? '0'),
  );
  Future<void> meta(DatabaseExecutor t, String key, String value) async {
    if (await t.update(
          'app_meta',
          {'value': value},
          where: 'key=?',
          whereArgs: [key],
        ) ==
        0) {
      await t.insert('app_meta', {
        'meta_id': r.id(),
        'key': key,
        'value': value,
      });
    }
  }

  Future<void> financialSettings(String base, int rate) =>
      r.db.transaction((t) async {
        if (!['USD', 'SYP'].contains(base) || rate <= 0 || rate > 1000000000000) {
          throw ArgumentError('سعر الصرف غير صالح');
        }
        await meta(t, 'base_currency', base);
        await meta(t, 'fx_rate_micros', '$rate');
        await r.audit(t, r.id(), 'fx.updated', {'base': base, 'rate': rate});
      });
  Future<void> seed() => r.db.transaction((t) async {
    await t.execute(
      'INSERT OR IGNORE INTO material_inventory(material_id,name_en) SELECT material_id,current_name FROM materials',
    );
    if ((await t.query(
      'app_meta',
      where: 'key=?',
      whereArgs: ['workspace_v4_seeded'],
    )).isNotEmpty) {
      return;
    }
    for (final v in [
      ['بوتكس', 'Botox', 'injection'],
      ['فيلر', 'Filler', 'injection'],
      ['ميزوثيرابي', 'Mesotherapy', 'injection'],
      ['حقن شحوم', 'Fat injection', 'injection'],
      ['استشارة جراحية', 'Surgical consultation', 'consultation'],
      ['استشارة حقن', 'Injection consultation', 'consultation'],
      ['جراحة موضعية', 'Local surgery', 'surgery'],
      ['جراحة ضمن المشفى', 'Hospital surgery', 'surgery'],
    ]) {
      await t.insert('procedures', {
        'procedure_id': r.id(),
        'name_ar': v[0],
        'name_en': v[1],
        'category': v[2],
      });
    }
    for (final v in [
      [
        'تعليمات ما قبل الإجراء',
        'instructions',
        'يرجى إبلاغ الطبيب بالأدوية والحساسية والأمراض السابقة. يحدد الطبيب التحضيرات المناسبة للإجراء.',
      ],
      [
        'تعليمات المتابعة بعد الإجراء',
        'instructions',
        'اتبع خطة الرعاية المحددة من الطبيب. عند ظهور ألم شديد أو تغير لون الجلد أو اضطراب الرؤية، تواصل مع الطبيب واطلب التقييم العاجل.',
      ],
      [
        'موافقة على الإجراء',
        'consent',
        'أقر بأن الطبيب شرح لي الإجراء ومنافعه ومخاطره والبدائل وأجاب عن أسئلتي. تستكمل تفاصيل الإجراء والموافقة بمراجعة الطبيب.',
      ],
    ]) {
      final id = r.id();
      await t.insert('documents', {
        'document_id': id,
        'kind': 'templates',
        'payload': await r.box.seal({
          'title': v[0],
          'type': v[1],
          'body': v[2],
        }, context: 'document:$id'),
      });
    }
    await meta(t, 'workspace_v4_seeded', '1');
  });
  Future<List<DbRow>> procedures({bool archived = false}) => r.db.query(
    'procedures',
    where: 'is_archived=? AND is_hidden=0',
    whereArgs: [archived ? 1 : 0],
    orderBy: 'name_ar',
  );
  Future<void> saveProcedure(
    String ar,
    String en,
    String category, {
    String? id,
  }) => r.db.transaction((t) async {
    if (ar.trim().isEmpty || en.trim().isEmpty) {
      throw ArgumentError('الاسمان مطلوبان');
    }
    final row = {
      'name_ar': ar.trim(),
      'name_en': en.trim(),
      'category': category,
    };
    if (id == null) {
      await t.insert('procedures', {'procedure_id': r.id(), ...row});
    } else {
      await t.update(
        'procedures',
        row,
        where: 'procedure_id=?',
        whereArgs: [id],
      );
    }
  });
  Future<void> archive(
    String table,
    String key,
    String id, {
    bool restore = false,
    bool hide = false,
  }) => r.db.transaction((t) async {
    if (const {
          'patients': 'patient_id',
          'materials': 'material_id',
          'procedures': 'procedure_id',
        }[table] !=
        key) {
      throw ArgumentError('Invalid archive target');
    }
    await t.update(
      table,
      {'is_archived': restore ? 0 : 1, 'is_hidden': hide ? 1 : 0},
      where: '$key=?',
      whereArgs: [id],
    );
    await r.audit(t, id, 'archive.changed', {
      'table': table,
      'restore': restore,
      'hidden': hide,
    });
  });
  Future<List<DbRow>> inventory() => r.db.rawQuery(
    """SELECT m.*,v.version_id,v.name,COALESCE(v.standard_unit,CASE WHEN v.unit='Units' THEN 'Unit' ELSE v.unit END) unit,v.unit_cost_minor,v.cost_known,i.name_ar,i.name_en,i.stock_milli,i.revision stock_revision FROM materials m JOIN material_versions v ON v.version_id=m.current_version_id JOIN material_inventory i ON i.material_id=m.material_id WHERE m.is_archived=0 AND m.is_hidden=0 ORDER BY m.current_name""",
  );
  Future<void> saveMaterial({
    DbRow? old,
    required String ar,
    required String en,
    required String unit,
    required int cost,
    required int stock,
    required Fx fx,
  }) => r.db.transaction((t) async {
    if (ar.trim().isEmpty ||
        en.trim().isEmpty ||
        !['Unit', 'CC', 'Syringe', 'Vial', 'Box'].contains(unit) ||
        stock < 0 ||
        stock > 1000000000) {
      throw ArgumentError('بيانات المادة غير صالحة');
    }
    String? mid = old?['material_id'] as String?;
    if (mid != null) {
      final fresh = (await t.rawQuery(
        'SELECT m.revision,i.revision stock_revision,i.stock_milli FROM materials m JOIN material_inventory i ON i.material_id=m.material_id WHERE m.material_id=?',
        [mid],
      )).single;
      if (fresh['revision'] != old!['revision'] ||
          fresh['stock_revision'] != old['stock_revision']) {
        throw StateError('تغير المخزون؛ أعد فتح المادة');
      }
      final used = await t.query(
        'session_materials',
        where: 'material_id=? AND quantity>0',
        whereArgs: [mid],
        limit: 1,
      );
      if (unit != old['unit'] && (used.isNotEmpty || fresh['stock_milli'] != 0)) {
        throw StateError('أنشئ مادة مستقلة لتغيير وحدة مادة مستخدمة أو متوفرة');
      }
    }
    final vid = await r.materialVersion(
      t,
      materialId: mid,
      name: en,
      unit: unit,
      cost: cost,
      currency: fx.ledger,
      rateMicros: fx.rateMicros > 0 ? fx.rateMicros : null,
    );
    mid ??=
        (await t.query(
              'material_versions',
              where: 'version_id=?',
              whereArgs: [vid],
            )).single['material_id']
            as String;
    await t.rawInsert(
      'INSERT OR IGNORE INTO material_inventory(material_id) VALUES(?)',
      [mid],
    );
    await t.rawUpdate(
      'UPDATE material_inventory SET name_ar=?,name_en=?,stock_milli=?,revision=revision+1 WHERE material_id=?',
      [ar, en, stock, mid],
    );
    final delta = stock - (old?['stock_milli'] as int? ?? 0);
    if (delta != 0) {
      await t.insert('stock_movements', {
        'movement_id': r.id(),
        'material_id': mid,
        'delta_milli': delta,
        'at': r.now(),
        'reason': 'physical stock adjustment',
      });
    }
    await r.audit(t, mid, 'inventory.version', {
      'version_id': vid,
      'delta': delta,
    });
  });
}
