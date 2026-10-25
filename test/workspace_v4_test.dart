import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tarraf_clinic/data/workspace_repository.dart';
import 'package:tarraf_clinic/data/report_repository.dart';
import 'package:tarraf_clinic/services/backup_service.dart';
import 'package:tarraf_clinic/domain/fx.dart';
import 'package:tarraf_clinic/domain/models.dart';
import 'data_model_test.dart' as f;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test(
    'fixed-point currency conversion and immutable ledger preference',
    () async {
      const fx = Fx('USD', 2, 'SYP', 12500500000);
      expect(fx.convert(100, 'USD', 2, 'SYP', 0), 12501);
      expect(fx.convert(1250050, 'SYP', 2, 'USD', 2), 100);
      expect(fx.parseInput('25001'), 200);
      expect(
        () => const Fx('USD', 2, 'SYP', 0).parseInput('1'),
        throwsStateError,
      );
      final r = await f.repository();
      addTearDown(r.db.close);
      final w = WorkspaceRepository(r);
      await w.financialSettings('SYP', 12000000000);
      expect(await r.currency, 'USD');
      expect(await r.digits, 2);
      expect((await w.fx()).base, 'SYP');
    },
  );
  test(
    'stock shortage rolls back point revision cost and quantity; edits and deletion release stock',
    () async {
      final r = await f.repository();
      addTearDown(r.db.close);
      final w = WorkspaceRepository(r);
      await w.seed();
      await w.financialSettings('USD', 12000000000);
      final fx = await w.fx();
      await w.saveMaterial(
        ar: 'فيلر',
        en: 'Filler',
        unit: 'Syringe',
        cost: 1000,
        stock: 3000,
        fx: fx,
      );
      final m = (await w.inventory()).single,
          vid = m['version_id'] as String,
          mid = m['material_id'] as String;
      final pid = await r.addPatient({'name': 'Test', 'allergies': 'latex'}),
          sid = await r.createSession(
            pid,
            procedure: 'Filler',
            category: 'injection',
            performedAt: DateTime.utc(2026, 10, 1),
          );
      Future<int> stock() async =>
          (await w.inventory()).single['stock_milli'] as int;
      await f.add(r, sid, vid, 1000);
      expect(await stock(), 2000);
      final point = (await r.points(sid)).single;
      await r.savePoint(
        sessionId: sid,
        revision: await f.revision(r, sid),
        pointId: point['point_id'] as String,
        versionId: vid,
        milliQuantity: 2000,
        x: .5,
        y: .5,
      );
      expect(await stock(), 1000);
      final rev = await f.revision(r, sid);
      await expectLater(f.add(r, sid, vid, 2000), throwsA(anything));
      expect(await stock(), 1000);
      expect(await f.revision(r, sid), rev);
      expect((await r.points(sid)).length, 1);
      await r.deletePoint(point['point_id'] as String, sid, rev);
      expect(await stock(), 3000);
      await f.add(r, sid, vid, 1000);
      await r.deleteDraft(sid);
      expect(await stock(), 3000);
      final sid2 = await r.createSession(
        pid,
        procedure: 'Filler',
        category: 'injection',
        performedAt: DateTime.utc(2026, 10, 2),
      );
      await f.add(r, sid2, vid, 1000);
      await f.approve(r, sid2, 5000);
      await w.saveMaterial(
        old: (await w.inventory()).single,
        ar: 'فيلر جديد',
        en: 'New Filler',
        unit: 'Syringe',
        cost: 2000,
        stock: 2000,
        fx: fx,
      );
      expect((await r.points(sid2)).single['version_id'], vid);
      expect((await r.points(sid2)).single['name'], 'Filler');
      expect(
        (await r.db.query(
          'session_materials',
          where: 'session_id=?',
          whereArgs: [sid2],
        )).single['approved_cost_minor'],
        1000,
      );
      await w.archive('materials', 'material_id', mid);
      expect(await w.inventory(), isEmpty);
      expect((await r.points(sid2)).length, 1);
      await w.archive('materials', 'material_id', mid, restore: true);
      expect((await w.inventory()).length, 1);
      await w.archive('patients', 'patient_id', pid);
      expect(await r.patients(), isEmpty);
      expect((await r.sessions(pid)).length, 1);
      await w.archive('patients', 'patient_id', pid, restore: true);
      expect((await r.patients()).length, 1);
    },
  );
  test('partial unpaid and fully paid filters are disjoint', () async {
    final r = await f.repository();
    addTearDown(r.db.close);
    final (pid, sid, vid) = await f.draft(r);
    await f.add(r, sid, vid, 1000);
    final charge = await f.approve(r, sid, 10000);
    await r.recordPayment(pid, 4000, DateTime.utc(2026, 1, 20), '', {
      charge: 4000,
    });
    final reports = ReportRepository(r);
    ReportFilter filter(String status) => ReportFilter(
      from: DateTime.utc(2026, 1),
      until: DateTime.utc(2026, 2),
      paymentStatus: status,
    );
    expect((await reports.run(filter('partial'))).fees, 10000);
    expect((await reports.run(filter('due'))).fees, 0);
    expect((await reports.run(filter('paid'))).fees, 0);
    await r.recordPayment(pid, 6000, DateTime.utc(2026, 1, 21), '', {
      charge: 6000,
    });
    expect((await reports.run(filter('paid'))).received, 10000);
    expect((await reports.run(filter('partial'))).fees, 0);
  });
  test(
    'inventory backup restores balances without charging clinical usage twice',
    () async {
      final r = await f.repository();
      addTearDown(r.db.close);
      final w = WorkspaceRepository(r);
      await w.seed();
      await w.financialSettings('USD', 12000000000);
      await w.saveMaterial(
        ar: 'مادة',
        en: 'Material',
        unit: 'Vial',
        cost: 500,
        stock: 2000,
        fx: await w.fx(),
      );
      final m = (await w.inventory()).single,
          pid = await r.addPatient({'name': 'Backup test'}),
          sid = await r.createSession(
            pid,
            procedure: 'Injection',
            category: 'injection',
            performedAt: DateTime.utc(2026, 10, 1),
          );
      await f.add(r, sid, m['version_id'] as String, 1000);
      await f.approve(r, sid, 1000);
      final target = await f.repository(configure: false);
      addTearDown(target.db.close);
      await BackupService(
        target,
      ).importPortable(target.db, await BackupService(r).portable());
      expect(
        (await WorkspaceRepository(target).inventory()).single['stock_milli'],
        1000,
      );
      expect((await target.points(sid)).single['units_or_cc'], 1000);
      expect(await target.db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );
  test('procedure UUID filter includes renamed procedure history', () async {
    final r = await f.repository();
    addTearDown(r.db.close);
    final w = WorkspaceRepository(r);
    await w.seed();
    final p = (await w.procedures()).first,
        pid = await r.addPatient({'name': 'Procedure UUID'}),
        sid = await r.createSession(
          pid,
          procedure: p['name_ar'] as String,
          category: p['category'] as String,
          procedureId: p['procedure_id'] as String,
          performedAt: DateTime.utc(2026, 10, 1),
        );
    await f.approve(r, sid, 5000);
    await w.saveProcedure(
      'اسم جديد',
      'Renamed',
      p['category'] as String,
      id: p['procedure_id'] as String,
    );
    final report = await ReportRepository(r).run(
      ReportFilter(
        from: DateTime.utc(2026, 10),
        until: DateTime.utc(2026, 11),
        procedureId: p['procedure_id'] as String,
      ),
    );
    expect(report.fees, 5000);
    expect(report.accrual.single['procedure_name'], p['name_ar']);
  });
}
