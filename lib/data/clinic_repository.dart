import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid/uuid.dart';
import '../domain/models.dart';
import '../domain/money.dart';
import 'crypto_box.dart';

class ClinicRepository {
  final Database db;
  final CryptoBox box;
  static const uuid = Uuid();
  ClinicRepository(this.db, this.box);
  String id() => uuid.v4();
  String now() => DateTime.now().toUtc().toIso8601String();
  Future<String?> meta(String key) async {
    final rows = await db.query('app_meta', where: 'key=?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<int> get digits async =>
      int.parse((await meta('minor_digits')) ?? '2');
  Future<String> get currency async => (await meta('currency')) ?? 'USD';
  Future<void> audit(
    DatabaseExecutor t,
    String entity,
    String action,
    Map<String, dynamic> data,
  ) async {
    final event = id();
    await t.insert('audit_events', {
      'event_id': event,
      'entity_id': entity,
      'action': action,
      'at': now(),
      'payload': await box.seal(data, context: 'audit:$event'),
    });
  }

  Future<String> addPatient(Map<String, dynamic> data) async {
    final pid = id();
    if ('${data['name'] ?? ''}'.trim().isEmpty) {
      throw ArgumentError('اسم المريض مطلوب');
    }
    await db.insert('patients', {
      'patient_id': pid,
      'payload': await box.seal(data, context: 'patient:$pid'),
    });
    return pid;
  }

  Future<void> editPatient(
    String patient,
    Map<String, dynamic> data,
    int revision,
  ) => db.transaction((t) async {
    if ('${data['name'] ?? ''}'.trim().isEmpty) {
      throw ArgumentError('اسم المريض مطلوب');
    }
    final count = await t.rawUpdate(
      'UPDATE patients SET payload=?,revision=revision+1 WHERE patient_id=? AND revision=?',
      [await box.seal(data, context: 'patient:$patient'), patient, revision],
    );
    if (count != 1) throw StateError('تغير الملف؛ أعد فتحه');
    await audit(t, patient, 'patient.edited', {});
  });
  Future<List<Map<String, dynamic>>> patients({bool archived = false}) async {
    final rows = await db.rawQuery(
      "SELECT p.*,(SELECT COUNT(*) FROM sessions s WHERE s.patient_id=p.patient_id AND s.status<>'cancelled') visit_count,(SELECT procedure_name FROM sessions s WHERE s.patient_id=p.patient_id AND s.status<>'cancelled' ORDER BY performed_at DESC LIMIT 1) last_procedure,(SELECT MAX(performed_at) FROM sessions s WHERE s.patient_id=p.patient_id AND s.status<>'cancelled') last_visit FROM patients p WHERE is_archived=? AND is_hidden=0",
      [archived ? 1 : 0],
    );
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final pid = row['patient_id'] as String;
      result.add({
        ...await box.open(row['payload'] as String, context: 'patient:$pid'),
        'patient_id': pid,
        'revision': row['revision'],
        'visit_count': row['visit_count'],
        'last_procedure': row['last_procedure'],
        'last_visit': row['last_visit'],
      });
    }
    return result;
  }

  Future<List<DbRow>> materials({bool archived = false}) => db.rawQuery(
    '''SELECT m.*,v.version_id,v.name,COALESCE(v.standard_unit,v.unit) unit,v.unit_cost_minor,v.currency,v.cost_known,i.name_ar,i.stock_milli
    FROM materials m JOIN material_versions v ON v.version_id=m.current_version_id
    LEFT JOIN material_inventory i ON i.material_id=m.material_id WHERE m.is_hidden=0 AND (?=1 OR m.is_archived=0) ORDER BY m.current_name''',
    [archived ? 1 : 0],
  );
  Future<String> materialVersion(
    DatabaseExecutor t, {
    String? materialId,
    required String name,
    required String unit,
    required int cost,
    required String currency,
    bool known = true,
    int? rateMicros,
  }) async {
    if (name.trim().isEmpty ||
        (!['Units', 'Unit', 'CC', 'Syringe', 'Vial', 'Box'].contains(unit) &&
            !(unit == 'Unknown' && !known))) {
      throw ArgumentError('بيانات المادة غير صالحة');
    }
    final mid = materialId ?? id(), vid = id();
    if (materialId == null) {
      await t.insert('materials', {
        'material_id': mid,
        'current_name': name.trim(),
      });
    }
    await t.insert('material_versions', {
      'version_id': vid,
      'material_id': mid,
      'name': name.trim(),
      'unit': unit == 'CC' || unit == 'Unknown' ? unit : 'Units',
      'standard_unit': unit == 'Unknown'
          ? null
          : (unit == 'Units' ? 'Unit' : unit),
      'fx_rate_micros': rateMicros,
      'unit_cost_minor': cost,
      'currency': currency,
      'cost_known': known ? 1 : 0,
      'created_at': now(),
    });
    await t.rawUpdate(
      'UPDATE materials SET current_name=?,current_version_id=?,revision=revision+1 WHERE material_id=?',
      [name.trim(), vid, mid],
    );
    if ((await t.query(
      'app_meta',
      where: 'key=?',
      whereArgs: ['workspace_v4_seeded'],
    )).isNotEmpty) {
      await t.rawInsert(
        'INSERT OR IGNORE INTO material_inventory(material_id,name_en) VALUES(?,?)',
        [mid, name.trim()],
      );
    }
    return vid;
  }

  Future<void> editMaterial({
    String? materialId,
    required String name,
    required String unit,
    required int cost,
    int? revision,
  }) async {
    final cur = await currency;
    await db.transaction((t) async {
      if (materialId != null) {
        final rows = await t.query(
          'materials',
          where: 'material_id=?',
          whereArgs: [materialId],
        );
        if (rows.isEmpty || rows.first['revision'] != revision) {
          throw StateError('المادة تغيرت؛ أعد فتحها');
        }
      }
      final vid = await materialVersion(
        t,
        materialId: materialId,
        name: name,
        unit: unit,
        cost: cost,
        currency: cur,
      );
      await audit(t, materialId ?? vid, 'material.version.created', {
        'version_id': vid,
      });
    });
  }

  Future<void> archiveMaterial(String materialId, bool archived) =>
      db.transaction((t) async {
        await t.update(
          'materials',
          {'is_archived': archived ? 1 : 0},
          where: 'material_id=?',
          whereArgs: [materialId],
        );
        await audit(t, materialId, 'material.archive', {'archived': archived});
      });
  Future<void> seedMaterials() async {
    if (await meta('catalog_seeded') == '1') return;
    final cur = await currency;
    await db.transaction((t) async {
      for (final name in [
        'Botox Allergan',
        'Dysport',
        'Xeomin',
        'Juvederm Voluma',
        'Juvederm Ultra',
        'Restylane',
        'Stylage',
        'Profhilo',
        'Sculptra',
        'Mesotherapy',
      ]) {
        await materialVersion(
          t,
          name: name,
          unit: ['Botox Allergan', 'Dysport', 'Xeomin'].contains(name)
              ? 'Units'
              : 'CC',
          cost: 0,
          currency: cur,
          known: false,
        );
      }
      await t.insert('app_meta', {
        'meta_id': id(),
        'key': 'catalog_seeded',
        'value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<String> createSession(
    String patient, {
    required String procedure,
    required String category,
    required DateTime performedAt,
    String notes = '',
    String diagram = 'face',
    String? procedureId,
  }) async {
    if (procedure.trim().isEmpty) throw ArgumentError('اسم الإجراء مطلوب');
    final sid = id();
    await db.insert('sessions', {
      'session_id': sid,
      'patient_id': patient,
      'performed_at': performedAt.toUtc().toIso8601String(),
      'status': 'draft',
      'notes': await box.seal({'notes': notes}, context: 'session:$sid'),
      'procedure_name': procedure,
      'procedure_id': procedureId,
      'category': category,
      'diagram': diagram,
      'created_at': now(),
      'updated_at': now(),
    });
    return sid;
  }

  Future<List<DbRow>> sessions(String patient) => db.query(
    'sessions',
    where: 'patient_id=?',
    whereArgs: [patient],
    orderBy: 'performed_at DESC',
  );
  Future<DbRow> session(String sid) async => (await db.query(
    'sessions',
    where: 'session_id=?',
    whereArgs: [sid],
  )).single;
  Future<void> revisionGuard(Transaction t, String sid, int expected) async {
    final count = await t.rawUpdate(
      "UPDATE sessions SET revision=revision+1,updated_at=? WHERE session_id=? AND revision=? AND status='draft'",
      [now(), sid, expected],
    );
    if (count != 1) throw StateError('الجلسة معتمدة أو تغيرت؛ أعد تحميلها');
  }

  Future<void> recalculate(DatabaseExecutor t, String usage) async {
    final rows = await t.rawQuery(
      '''SELECT m.*,v.unit_cost_minor,v.cost_known,COALESCE((SELECT SUM(p.units_or_cc) FROM injection_points p WHERE p.session_material_id=m.session_material_id),0) AS qty
      FROM session_materials m JOIN material_versions v ON v.version_id=m.version_id WHERE m.session_material_id=?''',
      [usage],
    );
    if (rows.isEmpty) return;
    final r = rows.single, qty = r['qty'] as int;
    final stock = await t.query(
      'material_inventory',
      where: 'material_id=?',
      whereArgs: [r['material_id']],
    );
    if (stock.isNotEmpty &&
        (stock.single['stock_milli'] as int) + (r['quantity'] as int) - qty < 0) {
      throw StateError('المخزون غير كافٍ / Insufficient stock');
    }
    final cost = r['cost_known'] == 1
        ? Money.consumption(qty, r['unit_cost_minor'] as int)
        : null;
    await t.update(
      'session_materials',
      {'quantity': qty, 'approved_cost_minor': cost},
      where: 'session_material_id=?',
      whereArgs: [usage],
    );
  }

  Future<void> savePoint({
    required String sessionId,
    required int revision,
    String? pointId,
    required String versionId,
    String? batchId,
    String lot = '',
    String? expiry,
    required int milliQuantity,
    required double x,
    required double y,
  }) => db.transaction((t) async {
    await revisionGuard(t, sessionId, revision);
    if (milliQuantity <= 0) throw ArgumentError('الكمية يجب أن تكون موجبة');
    final v = (await t.rawQuery(
      'SELECT v.*,m.is_archived FROM material_versions v JOIN materials m ON m.material_id=v.material_id WHERE v.version_id=?',
      [versionId],
    )).single;
    String? previousUsage;
    if (pointId != null) {
      final old = await t.rawQuery(
        'SELECT p.*,m.session_id FROM injection_points p JOIN session_materials m ON m.session_material_id=p.session_material_id WHERE p.point_id=?',
        [pointId],
      );
      if (old.isEmpty || old.single['session_id'] != sessionId) {
        throw StateError('نقطة غير موجودة في الجلسة');
      }
      previousUsage = old.single['session_material_id'] as String;
    }
    final previous = previousUsage == null
        ? <DbRow>[]
        : await t.query(
            'session_materials',
            where: 'session_material_id=?',
            whereArgs: [previousUsage],
          );
    if (v['is_archived'] == 1 &&
        (previous.isEmpty || previous.single['version_id'] != versionId)) {
      throw StateError('المادة مؤرشفة');
    }
    if (batchId == null && lot.trim().isNotEmpty) {
      final found = await t.query(
        'material_batches',
        where: 'material_id=? AND lot_number=?',
        whereArgs: [v['material_id'], lot.trim()],
      );
      batchId = found.isEmpty ? id() : found.single['batch_id'] as String;
      if (found.isEmpty) {
        await t.insert('material_batches', {
          'batch_id': batchId,
          'material_id': v['material_id'],
          'lot_number': lot.trim(),
          'expiry_date': expiry,
        });
      }
    }
    if (batchId != null) {
      final batch = await t.query(
        'material_batches',
        where: 'batch_id=? AND material_id=?',
        whereArgs: [batchId, v['material_id']],
      );
      if (batch.isEmpty) throw StateError('التشغيلة لا تخص المادة');
      final expiryDate = batch.single['expiry_date'] as String?;
      if (expiryDate != null &&
          expiryDate.compareTo(
                (await t.query(
                  'sessions',
                  where: 'session_id=?',
                  whereArgs: [sessionId],
                )).single['performed_at'].toString().substring(0, 10),
              ) <
              0) {
        throw StateError('التشغيلة منتهية بتاريخ الجلسة');
      }
    }
    final uses = await t.rawQuery(
      'SELECT * FROM session_materials WHERE session_id=? AND version_id=? AND ${batchId == null ? 'batch_id IS NULL' : 'batch_id=?'}',
      [sessionId, versionId, if (batchId != null) batchId],
    );
    final usage = uses.isEmpty
        ? id()
        : uses.single['session_material_id'] as String;
    if (uses.isEmpty) {
      await t.insert('session_materials', {
        'session_material_id': usage,
        'session_id': sessionId,
        'material_id': v['material_id'],
        'version_id': versionId,
        'batch_id': batchId,
        'quantity': 0,
        'approved_cost_minor': v['cost_known'] == 1 ? 0 : null,
      });
    }
    final pid = pointId ?? id();
    final order =
        (await t.rawQuery(
              'SELECT COALESCE(MAX(p.ordinal),0)+1 AS n FROM injection_points p JOIN session_materials m ON m.session_material_id=p.session_material_id WHERE m.session_id=?',
              [sessionId],
            )).single['n']
            as int;
    if (pointId == null) {
      await t.insert('injection_points', {
        'point_id': pid,
        'session_material_id': usage,
        'x_coord': x,
        'y_coord': y,
        'units_or_cc': milliQuantity,
        'ordinal': order,
        'created_at': now(),
      });
    } else {
      await t.update(
        'injection_points',
        {
          'session_material_id': usage,
          'x_coord': x,
          'y_coord': y,
          'units_or_cc': milliQuantity,
        },
        where: 'point_id=?',
        whereArgs: [pid],
      );
    }
    if (previousUsage != null && previousUsage != usage) {
      await recalculate(t, previousUsage);
    }
    await recalculate(t, usage);
    await audit(t, pid, 'point.saved', {
      'session_id': sessionId,
      'version_id': versionId,
      'quantity': milliQuantity,
    });
  });
  Future<void> deletePoint(
    String pid,
    String sid,
    int revision,
  ) => db.transaction((t) async {
    await revisionGuard(t, sid, revision);
    final p = await t.rawQuery(
      'SELECT p.session_material_id FROM injection_points p JOIN session_materials m ON m.session_material_id=p.session_material_id WHERE p.point_id=? AND m.session_id=?',
      [pid, sid],
    );
    if (p.isEmpty) throw StateError('النقطة غير موجودة');
    await t.delete('injection_points', where: 'point_id=?', whereArgs: [pid]);
    await recalculate(t, p.single['session_material_id'] as String);
    await audit(t, pid, 'point.deleted', {'session_id': sid});
  });
  Future<List<DbRow>> points(String sid) => db.rawQuery(
    '''SELECT p.*,m.version_id,m.batch_id,m.session_id,v.name,COALESCE(v.standard_unit,v.unit) unit,v.material_id,b.lot_number
    FROM injection_points p JOIN session_materials m ON m.session_material_id=p.session_material_id JOIN material_versions v ON v.version_id=m.version_id
    LEFT JOIN material_batches b ON b.batch_id=m.batch_id WHERE m.session_id=? ORDER BY p.ordinal,p.point_id''',
    [sid],
  );
  Future<List<DbRow>> history(String sid) => db.rawQuery(
    '''SELECT p.*,s.performed_at,v.name,v.unit FROM injection_points p
    JOIN session_materials m ON m.session_material_id=p.session_material_id JOIN sessions s ON s.session_id=m.session_id
    JOIN material_versions v ON v.version_id=m.version_id JOIN sessions current ON current.session_id=?
    WHERE s.patient_id=current.patient_id AND s.diagram=current.diagram AND s.performed_at<current.performed_at AND s.status IN('final','legacy') ORDER BY s.performed_at''',
    [sid],
  );
  Future<void> setCharge(
    String sid,
    int revision,
    int amount,
    String description,
  ) => db.transaction((t) async {
    await revisionGuard(t, sid, revision);
    final rows = await t.query(
      'charges',
      where: 'session_id=?',
      whereArgs: [sid],
    );
    if (rows.isEmpty) {
      await t.insert('charges', {
        'charge_id': id(),
        'session_id': sid,
        'amount_minor': amount,
        'description': description,
      });
    } else {
      await t.update(
        'charges',
        {'amount_minor': amount, 'description': description},
        where: 'charge_id=?',
        whereArgs: [rows.single['charge_id']],
      );
    }
    await audit(t, sid, 'charge.saved', {'amount_minor': amount});
  });
  Future<void> finalize(String sid, int revision) => db.transaction((t) async {
    await revisionGuard(t, sid, revision);
    final unknown = await t.rawQuery(
      'SELECT session_material_id FROM session_materials WHERE session_id=? AND quantity>0 AND approved_cost_minor IS NULL',
      [sid],
    );
    if (unknown.isNotEmpty) {
      throw StateError('حدد تكلفة المواد قبل اعتماد الجلسة');
    }
    final charge = await t.query(
      'charges',
      where: 'session_id=?',
      whereArgs: [sid],
    );
    if (charge.isEmpty) throw StateError('سجل الأتعاب قبل الاعتماد');
    await t.update(
      'sessions',
      {'status': 'final'},
      where: 'session_id=?',
      whereArgs: [sid],
    );
    await audit(t, sid, 'session.finalized', {});
  });
  Future<void> deleteDraft(String sid) => db.transaction((t) async {
    final s = (await t.query(
      'sessions',
      where: 'session_id=?',
      whereArgs: [sid],
    )).single;
    if (s['status'] != 'draft') throw StateError('يمكن حذف المسودات فقط');
    await t.delete('charges', where: 'session_id=?', whereArgs: [sid]);
    await t.delete('sessions', where: 'session_id=?', whereArgs: [sid]);
    await audit(t, sid, 'draft.deleted', {});
  });
  Future<void> cancelSession(String sid) => db.transaction((t) async {
    await t.update(
      'sessions',
      {'status': 'cancelled', 'updated_at': now()},
      where: 'session_id=?',
      whereArgs: [sid],
    );
    await audit(t, sid, 'session.cancelled', {});
  });
  Future<List<DbRow>> outstanding(String patient) => db.rawQuery(
    '''SELECT c.*,s.procedure_name,c.amount_minor-COALESCE((SELECT SUM(a.allocated_amount_minor) FROM payment_allocations a JOIN payments p ON p.payment_id=a.payment_id WHERE a.charge_id=c.charge_id AND p.voided_at IS NULL),0) AS due_minor
    FROM charges c JOIN sessions s ON s.session_id=c.session_id WHERE s.patient_id=? AND s.status IN('final','legacy') ORDER BY s.performed_at''',
    [patient],
  );
  Future<String> recordPayment(
    String patient,
    int amount,
    DateTime paidAt,
    String notes,
    Map<String, int> allocations,
  ) async {
    final pid = id();
    await db.transaction((t) async {
      await t.insert('payments', {
        'payment_id': pid,
        'patient_id': patient,
        'amount_minor': amount,
        'paid_at': paidAt.toUtc().toIso8601String(),
        'notes': await box.seal({'notes': notes}, context: 'payment:$pid'),
      });
      for (final e in allocations.entries) {
        await t.insert('payment_allocations', {
          'allocation_id': id(),
          'payment_id': pid,
          'charge_id': e.key,
          'allocated_amount_minor': e.value,
        });
      }
      await audit(t, pid, 'payment.received', {
        'amount_minor': amount,
        'allocations': allocations,
      });
    });
    return pid;
  }

  Future<void> voidPayment(String pid, String reason) =>
      db.transaction((t) async {
        final count = await t.update(
          'payments',
          {'voided_at': now()},
          where: 'payment_id=? AND voided_at IS NULL',
          whereArgs: [pid],
        );
        if (count != 1 || reason.trim().isEmpty) {
          throw StateError('سبب الإلغاء مطلوب');
        }
        await audit(t, pid, 'payment.voided', {'reason': reason});
      });
  Future<List<DbRow>> payments(String patient) => db.query(
    'payments',
    where: 'patient_id=?',
    whereArgs: [patient],
    orderBy: 'paid_at DESC',
  );
  Future<String> document(
    String kind,
    Map<String, dynamic> payload, {
    String? patient,
    String? documentId,
  }) async {
    final doc = documentId ?? id();
    await db.insert('documents', {
      'document_id': doc,
      'patient_id': patient,
      'kind': kind,
      'payload': await box.seal(payload, context: 'document:$doc'),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return doc;
  }

  Future<List<Map<String, dynamic>>> documents(
    String kind, {
    String? patient,
  }) async {
    final rows = await db.query(
      'documents',
      where: patient == null
          ? 'kind=? AND patient_id IS NULL'
          : 'kind=? AND patient_id=?',
      whereArgs: [kind, if (patient != null) patient],
    );
    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      final doc = row['document_id'] as String;
      out.add({
        ...await box.open(row['payload'] as String, context: 'document:$doc'),
        'id': doc,
      });
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> appointments() async {
    final rows = await db.rawQuery(
      "SELECT d.document_id,d.patient_id,d.payload FROM documents d JOIN patients p ON p.patient_id=d.patient_id WHERE d.kind='appointments' AND p.is_archived=0 AND p.is_hidden=0",
    );
    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      final doc = row['document_id'] as String;
      out.add({
        ...await box.open(row['payload'] as String, context: 'document:$doc'),
        'id': doc,
        'patient_id': row['patient_id'],
      });
    }
    out.sort((a, b) => '${a['at']}'.compareTo('${b['at']}'));
    return out;
  }

  Future<int> draftCount() async {
    final rows = await db.rawQuery(
      "SELECT COUNT(*) c FROM sessions WHERE status='draft'",
    );
    return rows.first['c'] as int;
  }

  Future<void> removeDocument(String id) =>
      db.delete('documents', where: 'document_id=?', whereArgs: [id]);
}
