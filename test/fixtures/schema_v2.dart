import 'package:sqflite_common/sqlite_api.dart';

/// Schema version 2. STRICT SQLite tables; money INTEGER, quantities milli-units.
class SchemaV2 {
  static const version = 2;
  static const tables = [
    'app_meta',
    'patients',
    'materials',
    'material_versions',
    'material_batches',
    'sessions',
    'session_materials',
    'injection_points',
    'charges',
    'payments',
    'payment_allocations',
    'documents',
    'legacy_archive',
    'migration_links',
    'audit_events',
  ];
  static String uuid(String name) =>
      "$name TEXT PRIMARY KEY NOT NULL CHECK(length($name)=36 AND substr($name,9,1)='-' AND substr($name,14,1)='-' AND substr($name,19,1)='-' AND substr($name,24,1)='-' AND length(replace($name,'-',''))=32 AND replace(lower($name),'-','') NOT GLOB '*[^0-9a-f]*')";
  static Future<void> create(DatabaseExecutor d) async {
    final pk = uuid;
    for (final sql in [
      'CREATE TABLE app_meta(${pk('meta_id')},key TEXT NOT NULL UNIQUE,value TEXT NOT NULL) STRICT',
      'CREATE TABLE patients(${pk('patient_id')},payload TEXT NOT NULL,revision INTEGER NOT NULL DEFAULT 0) STRICT',
      'CREATE TABLE materials(${pk('material_id')},current_name TEXT NOT NULL CHECK(length(trim(current_name))>0),is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN(0,1)),revision INTEGER NOT NULL DEFAULT 0,current_version_id TEXT,FOREIGN KEY(current_version_id,material_id) REFERENCES material_versions(version_id,material_id) ON DELETE RESTRICT) STRICT',
      "CREATE TABLE material_versions(${pk('version_id')},material_id TEXT NOT NULL REFERENCES materials(material_id) ON DELETE RESTRICT,name TEXT NOT NULL,unit TEXT NOT NULL CHECK(unit IN('Units','CC','Unknown')),unit_cost_minor INTEGER NOT NULL CHECK(unit_cost_minor BETWEEN 0 AND 900000000000000),currency TEXT NOT NULL CHECK(length(currency)=3),cost_known INTEGER NOT NULL DEFAULT 1 CHECK(cost_known IN(0,1)),created_at TEXT NOT NULL,UNIQUE(version_id,material_id)) STRICT",
      'CREATE TABLE material_batches(${pk('batch_id')},material_id TEXT NOT NULL REFERENCES materials(material_id) ON DELETE RESTRICT,lot_number TEXT NOT NULL CHECK(length(trim(lot_number))>0),expiry_date TEXT,UNIQUE(batch_id,material_id),UNIQUE(material_id,lot_number)) STRICT',
      "CREATE TABLE sessions(${pk('session_id')},patient_id TEXT NOT NULL REFERENCES patients(patient_id) ON DELETE RESTRICT,performed_at TEXT NOT NULL,status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN('draft','final','legacy','cancelled')),notes TEXT NOT NULL,cost_unresolved INTEGER NOT NULL DEFAULT 0 CHECK(cost_unresolved IN(0,1)),procedure_name TEXT NOT NULL,category TEXT NOT NULL,diagram TEXT NOT NULL DEFAULT 'face' CHECK(diagram IN('face','body')),created_at TEXT NOT NULL,updated_at TEXT NOT NULL,revision INTEGER NOT NULL DEFAULT 0) STRICT",
      'CREATE TABLE session_materials(${pk('session_material_id')},session_id TEXT NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,material_id TEXT NOT NULL,version_id TEXT NOT NULL,batch_id TEXT,quantity INTEGER NOT NULL DEFAULT 0 CHECK(quantity BETWEEN 0 AND 1000000000),approved_cost_minor INTEGER CHECK(approved_cost_minor BETWEEN 0 AND 900000000000000),FOREIGN KEY(version_id,material_id) REFERENCES material_versions(version_id,material_id) ON DELETE RESTRICT,FOREIGN KEY(batch_id,material_id) REFERENCES material_batches(batch_id,material_id) ON DELETE RESTRICT) STRICT',
      'CREATE TABLE injection_points(${pk('point_id')},session_material_id TEXT NOT NULL REFERENCES session_materials(session_material_id) ON DELETE CASCADE,x_coord REAL NOT NULL CHECK(x_coord BETWEEN 0 AND 1),y_coord REAL NOT NULL CHECK(y_coord BETWEEN 0 AND 1),units_or_cc INTEGER NOT NULL CHECK(units_or_cc BETWEEN 0 AND 1000000000),ordinal INTEGER NOT NULL CHECK(ordinal>0),created_at TEXT NOT NULL) STRICT',
      'CREATE TABLE charges(${pk('charge_id')},session_id TEXT NOT NULL REFERENCES sessions(session_id) ON DELETE RESTRICT,amount_minor INTEGER NOT NULL CHECK(amount_minor BETWEEN 0 AND 900000000000000),description TEXT NOT NULL) STRICT',
      'CREATE TABLE payments(${pk('payment_id')},patient_id TEXT NOT NULL REFERENCES patients(patient_id) ON DELETE RESTRICT,amount_minor INTEGER NOT NULL CHECK(amount_minor BETWEEN 1 AND 900000000000000),paid_at TEXT NOT NULL,notes TEXT NOT NULL,voided_at TEXT) STRICT',
      'CREATE TABLE payment_allocations(${pk('allocation_id')},payment_id TEXT NOT NULL REFERENCES payments(payment_id) ON DELETE RESTRICT,charge_id TEXT NOT NULL REFERENCES charges(charge_id) ON DELETE RESTRICT,allocated_amount_minor INTEGER NOT NULL CHECK(allocated_amount_minor>0),UNIQUE(payment_id,charge_id)) STRICT',
      'CREATE TABLE documents(${pk('document_id')},patient_id TEXT REFERENCES patients(patient_id) ON DELETE RESTRICT,kind TEXT NOT NULL,payload TEXT NOT NULL) STRICT',
      'CREATE TABLE legacy_archive(${pk('archive_id')},legacy_id TEXT NOT NULL UNIQUE,kind TEXT NOT NULL,payload TEXT NOT NULL) STRICT',
      'CREATE TABLE migration_links(${pk('link_id')},legacy_id TEXT NOT NULL UNIQUE,target_id TEXT NOT NULL,kind TEXT NOT NULL) STRICT',
      'CREATE TABLE audit_events(${pk('event_id')},entity_id TEXT NOT NULL,action TEXT NOT NULL,at TEXT NOT NULL,payload TEXT NOT NULL) STRICT',
      'CREATE INDEX ix_sessions_patient_date ON sessions(patient_id,performed_at)',
      'CREATE INDEX ix_sessions_date ON sessions(performed_at,status)',
      'CREATE INDEX ix_material_versions ON material_versions(material_id,created_at)',
      'CREATE INDEX ix_usage_session ON session_materials(session_id)',
      'CREATE INDEX ix_points_usage ON injection_points(session_material_id)',
      'CREATE INDEX ix_payments_date ON payments(paid_at)',
      'CREATE INDEX ix_alloc_charge ON payment_allocations(charge_id)',
      'CREATE INDEX ix_docs_patient ON documents(patient_id,kind)',
      "CREATE TRIGGER version_immutable BEFORE UPDATE ON material_versions BEGIN SELECT RAISE(ABORT,'Material versions are immutable'); END",
      "CREATE TRIGGER version_no_delete BEFORE DELETE ON material_versions BEGIN SELECT RAISE(ABORT,'Archive the material instead'); END",
      "CREATE TRIGGER session_date_immutable BEFORE UPDATE OF performed_at ON sessions WHEN OLD.status<>'draft' BEGIN SELECT RAISE(ABORT,'Historical date is immutable'); END",
      "CREATE TRIGGER session_final_lock BEFORE UPDATE ON sessions WHEN OLD.status IN('final','legacy','cancelled') AND (NEW.performed_at<>OLD.performed_at OR NEW.patient_id<>OLD.patient_id OR NEW.procedure_name<>OLD.procedure_name OR NEW.category<>OLD.category OR NEW.notes<>OLD.notes OR NEW.diagram<>OLD.diagram OR NEW.status NOT IN(OLD.status,'cancelled')) BEGIN SELECT RAISE(ABORT,'Approved session is immutable'); END",
      "CREATE TRIGGER session_no_delete BEFORE DELETE ON sessions WHEN OLD.status<>'draft' BEGIN SELECT RAISE(ABORT,'Archive approved sessions'); END",
      "CREATE TRIGGER session_no_void_paid BEFORE UPDATE OF status ON sessions WHEN NEW.status='cancelled' AND EXISTS(SELECT 1 FROM charges c JOIN payment_allocations a ON a.charge_id=c.charge_id JOIN payments p ON p.payment_id=a.payment_id WHERE c.session_id=OLD.session_id AND p.voided_at IS NULL) BEGIN SELECT RAISE(ABORT,'Void related payments before cancelling'); END",
      "CREATE TRIGGER payment_immutable BEFORE UPDATE ON payments WHEN NEW.amount_minor<>OLD.amount_minor OR NEW.patient_id<>OLD.patient_id OR NEW.paid_at<>OLD.paid_at OR NEW.notes<>OLD.notes OR OLD.voided_at IS NOT NULL BEGIN SELECT RAISE(ABORT,'Payments are immutable; void and replace'); END",
      "CREATE TRIGGER payment_no_delete BEFORE DELETE ON payments BEGIN SELECT RAISE(ABORT,'Void payment instead'); END",
      "CREATE TRIGGER allocation_no_update BEFORE UPDATE ON payment_allocations BEGIN SELECT RAISE(ABORT,'Allocations are immutable'); END",
      "CREATE TRIGGER allocation_no_delete BEFORE DELETE ON payment_allocations BEGIN SELECT RAISE(ABORT,'Void payment instead'); END",
      """CREATE TRIGGER allocation_guard BEFORE INSERT ON payment_allocations BEGIN
        SELECT CASE WHEN (SELECT voided_at FROM payments WHERE payment_id=NEW.payment_id) IS NOT NULL THEN RAISE(ABORT,'Payment voided') END;
        SELECT CASE WHEN (SELECT p.patient_id FROM payments p WHERE p.payment_id=NEW.payment_id)<>(SELECT s.patient_id FROM charges c JOIN sessions s ON s.session_id=c.session_id WHERE c.charge_id=NEW.charge_id) THEN RAISE(ABORT,'Patient mismatch') END;
        SELECT CASE WHEN (SELECT s.status FROM charges c JOIN sessions s ON s.session_id=c.session_id WHERE c.charge_id=NEW.charge_id) NOT IN('final','legacy') THEN RAISE(ABORT,'Session not approved') END;
        SELECT CASE WHEN NEW.allocated_amount_minor+COALESCE((SELECT SUM(allocated_amount_minor) FROM payment_allocations WHERE payment_id=NEW.payment_id),0)>(SELECT amount_minor FROM payments WHERE payment_id=NEW.payment_id) THEN RAISE(ABORT,'Payment overallocated') END;
        SELECT CASE WHEN NEW.allocated_amount_minor+COALESCE((SELECT SUM(a.allocated_amount_minor) FROM payment_allocations a JOIN payments p ON p.payment_id=a.payment_id WHERE a.charge_id=NEW.charge_id AND p.voided_at IS NULL),0)>(SELECT amount_minor FROM charges WHERE charge_id=NEW.charge_id) THEN RAISE(ABORT,'Charge overpaid') END;
      END""",
    ]) {
      await d.execute(sql);
    }
    for (final sql in [
      "CREATE TRIGGER session_patient_fixed BEFORE UPDATE OF patient_id ON sessions WHEN OLD.patient_id<>NEW.patient_id BEGIN SELECT RAISE(ABORT,'Patient link is immutable'); END",
      "CREATE TRIGGER usage_session_fixed BEFORE UPDATE OF session_id ON session_materials WHEN OLD.session_id<>NEW.session_id BEGIN SELECT RAISE(ABORT,'Usage cannot move between sessions'); END",
      "CREATE TRIGGER charge_session_fixed BEFORE UPDATE OF session_id ON charges WHEN OLD.session_id<>NEW.session_id BEGIN SELECT RAISE(ABORT,'Charge cannot move between sessions'); END",
      "CREATE TRIGGER point_move_guard BEFORE UPDATE ON injection_points WHEN (SELECT s.status FROM session_materials m JOIN sessions s ON s.session_id=m.session_id WHERE m.session_material_id=OLD.session_material_id)<>'draft' OR (SELECT session_id FROM session_materials WHERE session_material_id=OLD.session_material_id)<>(SELECT session_id FROM session_materials WHERE session_material_id=NEW.session_material_id) BEGIN SELECT RAISE(ABORT,'Historical point cannot move'); END",
      """CREATE TRIGGER approve_guard BEFORE UPDATE OF status ON sessions WHEN NEW.status='final' AND OLD.status='draft' BEGIN
        SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM charges WHERE session_id=NEW.session_id) THEN RAISE(ABORT,'Fees required') END;
        SELECT CASE WHEN NEW.cost_unresolved<>0 THEN RAISE(ABORT,'Unknown session cost') END;
        SELECT CASE WHEN EXISTS(SELECT 1 FROM session_materials m JOIN material_versions v ON v.version_id=m.version_id WHERE m.session_id=NEW.session_id AND
          (m.quantity<>COALESCE((SELECT SUM(p.units_or_cc) FROM injection_points p WHERE p.session_material_id=m.session_material_id),0)
           OR (m.quantity>0 AND (v.cost_known=0 OR m.approved_cost_minor IS NULL)))) THEN RAISE(ABORT,'Invalid material totals') END;
        SELECT CASE WHEN EXISTS(SELECT 1 FROM session_materials m JOIN material_versions v ON v.version_id=m.version_id WHERE m.session_id=NEW.session_id AND v.unit_cost_minor>0 AND m.quantity>9000000000000000000/v.unit_cost_minor) THEN RAISE(ABORT,'Cost overflow') END;
        SELECT CASE WHEN EXISTS(SELECT 1 FROM session_materials m JOIN material_versions v ON v.version_id=m.version_id WHERE m.session_id=NEW.session_id AND v.cost_known=1 AND m.approved_cost_minor<>(m.quantity*v.unit_cost_minor+500)/1000) THEN RAISE(ABORT,'Cost mismatch') END;
      END""",
    ]) {
      await d.execute(sql);
    }
    // Both direct SQL and repository writes obey draft-only edit rules.
    for (final table in ['session_materials', 'charges']) {
      for (final op in ['INSERT', 'UPDATE', 'DELETE']) {
        final r = op == 'DELETE' ? 'OLD' : 'NEW';
        await d.execute(
          "CREATE TRIGGER ${table}_${op.toLowerCase()}_draft BEFORE $op ON $table WHEN (SELECT status FROM sessions WHERE session_id=$r.session_id)<>'draft' BEGIN SELECT RAISE(ABORT,'Session is locked'); END",
        );
      }
    }
    for (final op in ['INSERT', 'UPDATE', 'DELETE']) {
      final r = op == 'DELETE' ? 'OLD' : 'NEW';
      await d.execute(
        "CREATE TRIGGER points_${op.toLowerCase()}_draft BEFORE $op ON injection_points WHEN (SELECT s.status FROM session_materials m JOIN sessions s ON s.session_id=m.session_id WHERE m.session_material_id=$r.session_material_id)<>'draft' BEGIN SELECT RAISE(ABORT,'Session is locked'); END",
      );
    }
  }
}
