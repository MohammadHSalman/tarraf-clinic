PRAGMA foreign_keys=ON;
BEGIN;
CREATE TABLE app_meta(meta_id TEXT PRIMARY KEY NOT NULL CHECK(length(meta_id)=36 AND substr(meta_id,9,1)='-' AND substr(meta_id,14,1)='-' AND substr(meta_id,19,1)='-' AND substr(meta_id,24,1)='-' AND length(replace(meta_id,'-',''))=32 AND replace(lower(meta_id),'-','') NOT GLOB '*[^0-9a-f]*'),key TEXT NOT NULL UNIQUE,value TEXT NOT NULL) STRICT;

CREATE TABLE audit_events(event_id TEXT PRIMARY KEY NOT NULL CHECK(length(event_id)=36 AND substr(event_id,9,1)='-' AND substr(event_id,14,1)='-' AND substr(event_id,19,1)='-' AND substr(event_id,24,1)='-' AND length(replace(event_id,'-',''))=32 AND replace(lower(event_id),'-','') NOT GLOB '*[^0-9a-f]*'),entity_id TEXT NOT NULL,action TEXT NOT NULL,at TEXT NOT NULL,payload TEXT NOT NULL) STRICT;

CREATE TABLE charges(charge_id TEXT PRIMARY KEY NOT NULL CHECK(length(charge_id)=36 AND substr(charge_id,9,1)='-' AND substr(charge_id,14,1)='-' AND substr(charge_id,19,1)='-' AND substr(charge_id,24,1)='-' AND length(replace(charge_id,'-',''))=32 AND replace(lower(charge_id),'-','') NOT GLOB '*[^0-9a-f]*'),session_id TEXT NOT NULL REFERENCES sessions(session_id) ON DELETE RESTRICT,amount_minor INTEGER NOT NULL CHECK(amount_minor BETWEEN 0 AND 900000000000000),description TEXT NOT NULL) STRICT;

CREATE TABLE documents(document_id TEXT PRIMARY KEY NOT NULL CHECK(length(document_id)=36 AND substr(document_id,9,1)='-' AND substr(document_id,14,1)='-' AND substr(document_id,19,1)='-' AND substr(document_id,24,1)='-' AND length(replace(document_id,'-',''))=32 AND replace(lower(document_id),'-','') NOT GLOB '*[^0-9a-f]*'),patient_id TEXT REFERENCES patients(patient_id) ON DELETE RESTRICT,kind TEXT NOT NULL,payload TEXT NOT NULL) STRICT;

CREATE TABLE injection_points(point_id TEXT PRIMARY KEY NOT NULL CHECK(length(point_id)=36 AND substr(point_id,9,1)='-' AND substr(point_id,14,1)='-' AND substr(point_id,19,1)='-' AND substr(point_id,24,1)='-' AND length(replace(point_id,'-',''))=32 AND replace(lower(point_id),'-','') NOT GLOB '*[^0-9a-f]*'),session_material_id TEXT NOT NULL REFERENCES session_materials(session_material_id) ON DELETE CASCADE,x_coord REAL NOT NULL CHECK(x_coord BETWEEN 0 AND 1),y_coord REAL NOT NULL CHECK(y_coord BETWEEN 0 AND 1),units_or_cc INTEGER NOT NULL CHECK(units_or_cc BETWEEN 0 AND 1000000000),ordinal INTEGER NOT NULL CHECK(ordinal>0),created_at TEXT NOT NULL) STRICT;

CREATE TABLE legacy_archive(archive_id TEXT PRIMARY KEY NOT NULL CHECK(length(archive_id)=36 AND substr(archive_id,9,1)='-' AND substr(archive_id,14,1)='-' AND substr(archive_id,19,1)='-' AND substr(archive_id,24,1)='-' AND length(replace(archive_id,'-',''))=32 AND replace(lower(archive_id),'-','') NOT GLOB '*[^0-9a-f]*'),legacy_id TEXT NOT NULL UNIQUE,kind TEXT NOT NULL,payload TEXT NOT NULL) STRICT;

CREATE TABLE material_batches(batch_id TEXT PRIMARY KEY NOT NULL CHECK(length(batch_id)=36 AND substr(batch_id,9,1)='-' AND substr(batch_id,14,1)='-' AND substr(batch_id,19,1)='-' AND substr(batch_id,24,1)='-' AND length(replace(batch_id,'-',''))=32 AND replace(lower(batch_id),'-','') NOT GLOB '*[^0-9a-f]*'),material_id TEXT NOT NULL REFERENCES materials(material_id) ON DELETE RESTRICT,lot_number TEXT NOT NULL CHECK(length(trim(lot_number))>0),expiry_date TEXT,UNIQUE(batch_id,material_id),UNIQUE(material_id,lot_number)) STRICT;

CREATE TABLE material_inventory(material_id TEXT PRIMARY KEY REFERENCES materials(material_id) ON DELETE RESTRICT,name_ar TEXT NOT NULL DEFAULT '',name_en TEXT NOT NULL DEFAULT '',stock_milli INTEGER NOT NULL DEFAULT 0 CHECK(stock_milli BETWEEN 0 AND 1000000000),revision INTEGER NOT NULL DEFAULT 0) STRICT;

CREATE TABLE material_versions(version_id TEXT PRIMARY KEY NOT NULL CHECK(length(version_id)=36 AND substr(version_id,9,1)='-' AND substr(version_id,14,1)='-' AND substr(version_id,19,1)='-' AND substr(version_id,24,1)='-' AND length(replace(version_id,'-',''))=32 AND replace(lower(version_id),'-','') NOT GLOB '*[^0-9a-f]*'),material_id TEXT NOT NULL REFERENCES materials(material_id) ON DELETE RESTRICT,name TEXT NOT NULL,unit TEXT NOT NULL CHECK(unit IN('Units','CC','Unknown')),unit_cost_minor INTEGER NOT NULL CHECK(unit_cost_minor BETWEEN 0 AND 900000000000000),currency TEXT NOT NULL CHECK(length(currency)=3),cost_known INTEGER NOT NULL DEFAULT 1 CHECK(cost_known IN(0,1)),created_at TEXT NOT NULL, standard_unit TEXT CHECK(standard_unit IN('Unit','CC','Syringe','Vial','Box')), fx_rate_micros INTEGER CHECK(fx_rate_micros>0),UNIQUE(version_id,material_id)) STRICT;

CREATE TABLE materials(material_id TEXT PRIMARY KEY NOT NULL CHECK(length(material_id)=36 AND substr(material_id,9,1)='-' AND substr(material_id,14,1)='-' AND substr(material_id,19,1)='-' AND substr(material_id,24,1)='-' AND length(replace(material_id,'-',''))=32 AND replace(lower(material_id),'-','') NOT GLOB '*[^0-9a-f]*'),current_name TEXT NOT NULL CHECK(length(trim(current_name))>0),is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN(0,1)),revision INTEGER NOT NULL DEFAULT 0,current_version_id TEXT, is_hidden INTEGER NOT NULL DEFAULT 0 CHECK(is_hidden IN(0,1)),FOREIGN KEY(current_version_id,material_id) REFERENCES material_versions(version_id,material_id) ON DELETE RESTRICT) STRICT;

CREATE TABLE migration_links(link_id TEXT PRIMARY KEY NOT NULL CHECK(length(link_id)=36 AND substr(link_id,9,1)='-' AND substr(link_id,14,1)='-' AND substr(link_id,19,1)='-' AND substr(link_id,24,1)='-' AND length(replace(link_id,'-',''))=32 AND replace(lower(link_id),'-','') NOT GLOB '*[^0-9a-f]*'),legacy_id TEXT NOT NULL UNIQUE,target_id TEXT NOT NULL,kind TEXT NOT NULL) STRICT;

CREATE TABLE patients(patient_id TEXT PRIMARY KEY NOT NULL CHECK(length(patient_id)=36 AND substr(patient_id,9,1)='-' AND substr(patient_id,14,1)='-' AND substr(patient_id,19,1)='-' AND substr(patient_id,24,1)='-' AND length(replace(patient_id,'-',''))=32 AND replace(lower(patient_id),'-','') NOT GLOB '*[^0-9a-f]*'),payload TEXT NOT NULL,revision INTEGER NOT NULL DEFAULT 0, is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN(0,1)), is_hidden INTEGER NOT NULL DEFAULT 0 CHECK(is_hidden IN(0,1))) STRICT;

CREATE TABLE payment_allocations(allocation_id TEXT PRIMARY KEY NOT NULL CHECK(length(allocation_id)=36 AND substr(allocation_id,9,1)='-' AND substr(allocation_id,14,1)='-' AND substr(allocation_id,19,1)='-' AND substr(allocation_id,24,1)='-' AND length(replace(allocation_id,'-',''))=32 AND replace(lower(allocation_id),'-','') NOT GLOB '*[^0-9a-f]*'),payment_id TEXT NOT NULL REFERENCES payments(payment_id) ON DELETE RESTRICT,charge_id TEXT NOT NULL REFERENCES charges(charge_id) ON DELETE RESTRICT,allocated_amount_minor INTEGER NOT NULL CHECK(allocated_amount_minor>0),UNIQUE(payment_id,charge_id)) STRICT;

CREATE TABLE payments(payment_id TEXT PRIMARY KEY NOT NULL CHECK(length(payment_id)=36 AND substr(payment_id,9,1)='-' AND substr(payment_id,14,1)='-' AND substr(payment_id,19,1)='-' AND substr(payment_id,24,1)='-' AND length(replace(payment_id,'-',''))=32 AND replace(lower(payment_id),'-','') NOT GLOB '*[^0-9a-f]*'),patient_id TEXT NOT NULL REFERENCES patients(patient_id) ON DELETE RESTRICT,amount_minor INTEGER NOT NULL CHECK(amount_minor BETWEEN 1 AND 900000000000000),paid_at TEXT NOT NULL,notes TEXT NOT NULL,voided_at TEXT) STRICT;

CREATE TABLE procedures(procedure_id TEXT PRIMARY KEY NOT NULL CHECK(length(procedure_id)=36 AND substr(procedure_id,9,1)='-' AND substr(procedure_id,14,1)='-' AND substr(procedure_id,19,1)='-' AND substr(procedure_id,24,1)='-' AND length(replace(procedure_id,'-',''))=32 AND replace(lower(procedure_id),'-','') NOT GLOB '*[^0-9a-f]*'),name_ar TEXT NOT NULL,name_en TEXT NOT NULL,category TEXT NOT NULL CHECK(category IN('surgery','consultation','injection')),is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN(0,1)),is_hidden INTEGER NOT NULL DEFAULT 0 CHECK(is_hidden IN(0,1))) STRICT;

CREATE TABLE session_materials(session_material_id TEXT PRIMARY KEY NOT NULL CHECK(length(session_material_id)=36 AND substr(session_material_id,9,1)='-' AND substr(session_material_id,14,1)='-' AND substr(session_material_id,19,1)='-' AND substr(session_material_id,24,1)='-' AND length(replace(session_material_id,'-',''))=32 AND replace(lower(session_material_id),'-','') NOT GLOB '*[^0-9a-f]*'),session_id TEXT NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,material_id TEXT NOT NULL,version_id TEXT NOT NULL,batch_id TEXT,quantity INTEGER NOT NULL DEFAULT 0 CHECK(quantity BETWEEN 0 AND 1000000000),approved_cost_minor INTEGER CHECK(approved_cost_minor BETWEEN 0 AND 900000000000000),FOREIGN KEY(version_id,material_id) REFERENCES material_versions(version_id,material_id) ON DELETE RESTRICT,FOREIGN KEY(batch_id,material_id) REFERENCES material_batches(batch_id,material_id) ON DELETE RESTRICT) STRICT;

CREATE TABLE sessions(session_id TEXT PRIMARY KEY NOT NULL CHECK(length(session_id)=36 AND substr(session_id,9,1)='-' AND substr(session_id,14,1)='-' AND substr(session_id,19,1)='-' AND substr(session_id,24,1)='-' AND length(replace(session_id,'-',''))=32 AND replace(lower(session_id),'-','') NOT GLOB '*[^0-9a-f]*'),patient_id TEXT NOT NULL REFERENCES patients(patient_id) ON DELETE RESTRICT,performed_at TEXT NOT NULL,status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN('draft','final','legacy','cancelled')),notes TEXT NOT NULL,cost_unresolved INTEGER NOT NULL DEFAULT 0 CHECK(cost_unresolved IN(0,1)),procedure_name TEXT NOT NULL,category TEXT NOT NULL,diagram TEXT NOT NULL DEFAULT 'face' CHECK(diagram IN('face','body')),created_at TEXT NOT NULL,updated_at TEXT NOT NULL,revision INTEGER NOT NULL DEFAULT 0, procedure_id TEXT REFERENCES procedures(procedure_id) ON DELETE RESTRICT) STRICT;

CREATE TABLE stock_movements(movement_id TEXT PRIMARY KEY NOT NULL CHECK(length(movement_id)=36 AND substr(movement_id,9,1)='-' AND substr(movement_id,14,1)='-' AND substr(movement_id,19,1)='-' AND substr(movement_id,24,1)='-' AND length(replace(movement_id,'-',''))=32 AND replace(lower(movement_id),'-','') NOT GLOB '*[^0-9a-f]*'),material_id TEXT NOT NULL REFERENCES materials(material_id) ON DELETE RESTRICT,delta_milli INTEGER NOT NULL,at TEXT NOT NULL,reason TEXT NOT NULL) STRICT;

CREATE INDEX ix_alloc_charge ON payment_allocations(charge_id);

CREATE INDEX ix_docs_patient ON documents(patient_id,kind);

CREATE INDEX ix_material_versions ON material_versions(material_id,created_at);

CREATE INDEX ix_payments_date ON payments(paid_at);

CREATE INDEX ix_points_usage ON injection_points(session_material_id);

CREATE INDEX ix_sessions_date ON sessions(performed_at,status);

CREATE INDEX ix_sessions_patient_date ON sessions(patient_id,performed_at);

CREATE INDEX ix_usage_session ON session_materials(session_id);

CREATE TRIGGER allocation_guard BEFORE INSERT ON payment_allocations BEGIN
        SELECT CASE WHEN (SELECT voided_at FROM payments WHERE payment_id=NEW.payment_id) IS NOT NULL THEN RAISE(ABORT,'Payment voided') END;
        SELECT CASE WHEN (SELECT p.patient_id FROM payments p WHERE p.payment_id=NEW.payment_id)<>(SELECT s.patient_id FROM charges c JOIN sessions s ON s.session_id=c.session_id WHERE c.charge_id=NEW.charge_id) THEN RAISE(ABORT,'Patient mismatch') END;
        SELECT CASE WHEN (SELECT s.status FROM charges c JOIN sessions s ON s.session_id=c.session_id WHERE c.charge_id=NEW.charge_id) NOT IN('final','legacy') THEN RAISE(ABORT,'Session not approved') END;
        SELECT CASE WHEN NEW.allocated_amount_minor+COALESCE((SELECT SUM(allocated_amount_minor) FROM payment_allocations WHERE payment_id=NEW.payment_id),0)>(SELECT amount_minor FROM payments WHERE payment_id=NEW.payment_id) THEN RAISE(ABORT,'Payment overallocated') END;
        SELECT CASE WHEN NEW.allocated_amount_minor+COALESCE((SELECT SUM(a.allocated_amount_minor) FROM payment_allocations a JOIN payments p ON p.payment_id=a.payment_id WHERE a.charge_id=NEW.charge_id AND p.voided_at IS NULL),0)>(SELECT amount_minor FROM charges WHERE charge_id=NEW.charge_id) THEN RAISE(ABORT,'Charge overpaid') END;
      END;

CREATE TRIGGER allocation_no_delete BEFORE DELETE ON payment_allocations BEGIN SELECT RAISE(ABORT,'Void payment instead'); END;

CREATE TRIGGER allocation_no_update BEFORE UPDATE ON payment_allocations BEGIN SELECT RAISE(ABORT,'Allocations are immutable'); END;

CREATE TRIGGER approve_guard BEFORE UPDATE OF status ON sessions WHEN NEW.status='final' AND OLD.status='draft' BEGIN
        SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM charges WHERE session_id=NEW.session_id) THEN RAISE(ABORT,'Fees required') END;
        SELECT CASE WHEN NEW.cost_unresolved<>0 THEN RAISE(ABORT,'Unknown session cost') END;
        SELECT CASE WHEN EXISTS(SELECT 1 FROM session_materials m JOIN material_versions v ON v.version_id=m.version_id WHERE m.session_id=NEW.session_id AND
          (m.quantity<>COALESCE((SELECT SUM(p.units_or_cc) FROM injection_points p WHERE p.session_material_id=m.session_material_id),0)
           OR (m.quantity>0 AND (v.cost_known=0 OR m.approved_cost_minor IS NULL)))) THEN RAISE(ABORT,'Invalid material totals') END;
        SELECT CASE WHEN EXISTS(SELECT 1 FROM session_materials m JOIN material_versions v ON v.version_id=m.version_id WHERE m.session_id=NEW.session_id AND v.unit_cost_minor>0 AND m.quantity>9000000000000000000/v.unit_cost_minor) THEN RAISE(ABORT,'Cost overflow') END;
        SELECT CASE WHEN EXISTS(SELECT 1 FROM session_materials m JOIN material_versions v ON v.version_id=m.version_id WHERE m.session_id=NEW.session_id AND v.cost_known=1 AND m.approved_cost_minor<>(m.quantity*v.unit_cost_minor+500)/1000) THEN RAISE(ABORT,'Cost mismatch') END;
      END;

CREATE TRIGGER charge_session_fixed BEFORE UPDATE OF session_id ON charges WHEN OLD.session_id<>NEW.session_id BEGIN SELECT RAISE(ABORT,'Charge cannot move between sessions'); END;

CREATE TRIGGER charges_delete_draft BEFORE DELETE ON charges WHEN (SELECT status FROM sessions WHERE session_id=OLD.session_id)<>'draft' BEGIN SELECT RAISE(ABORT,'Session is locked'); END;

CREATE TRIGGER charges_insert_draft BEFORE INSERT ON charges WHEN (SELECT status FROM sessions WHERE session_id=NEW.session_id)<>'draft' BEGIN SELECT RAISE(ABORT,'Session is locked'); END;

CREATE TRIGGER charges_update_draft BEFORE UPDATE ON charges WHEN (SELECT status FROM sessions WHERE session_id=NEW.session_id)<>'draft' BEGIN SELECT RAISE(ABORT,'Session is locked'); END;

CREATE TRIGGER payment_immutable BEFORE UPDATE ON payments WHEN NEW.amount_minor<>OLD.amount_minor OR NEW.patient_id<>OLD.patient_id OR NEW.paid_at<>OLD.paid_at OR NEW.notes<>OLD.notes OR OLD.voided_at IS NOT NULL BEGIN SELECT RAISE(ABORT,'Payments are immutable; void and replace'); END;

CREATE TRIGGER payment_no_delete BEFORE DELETE ON payments BEGIN SELECT RAISE(ABORT,'Void payment instead'); END;

CREATE TRIGGER point_move_guard BEFORE UPDATE ON injection_points WHEN (SELECT s.status FROM session_materials m JOIN sessions s ON s.session_id=m.session_id WHERE m.session_material_id=OLD.session_material_id)<>'draft' OR (SELECT session_id FROM session_materials WHERE session_material_id=OLD.session_material_id)<>(SELECT session_id FROM session_materials WHERE session_material_id=NEW.session_material_id) BEGIN SELECT RAISE(ABORT,'Historical point cannot move'); END;

CREATE TRIGGER points_delete_draft BEFORE DELETE ON injection_points WHEN (SELECT s.status FROM session_materials m JOIN sessions s ON s.session_id=m.session_id WHERE m.session_material_id=OLD.session_material_id)<>'draft' BEGIN SELECT RAISE(ABORT,'Session is locked'); END;

CREATE TRIGGER points_insert_draft BEFORE INSERT ON injection_points WHEN (SELECT s.status FROM session_materials m JOIN sessions s ON s.session_id=m.session_id WHERE m.session_material_id=NEW.session_material_id)<>'draft' BEGIN SELECT RAISE(ABORT,'Session is locked'); END;

CREATE TRIGGER points_update_draft BEFORE UPDATE ON injection_points WHEN (SELECT s.status FROM session_materials m JOIN sessions s ON s.session_id=m.session_id WHERE m.session_material_id=NEW.session_material_id)<>'draft' BEGIN SELECT RAISE(ABORT,'Session is locked'); END;

CREATE TRIGGER session_date_immutable BEFORE UPDATE OF performed_at ON sessions WHEN OLD.status<>'draft' BEGIN SELECT RAISE(ABORT,'Historical date is immutable'); END;

CREATE TRIGGER session_final_lock BEFORE UPDATE ON sessions WHEN OLD.status IN('final','legacy','cancelled') AND (NEW.performed_at<>OLD.performed_at OR NEW.patient_id<>OLD.patient_id OR NEW.procedure_name<>OLD.procedure_name OR NEW.category<>OLD.category OR NEW.notes<>OLD.notes OR NEW.diagram<>OLD.diagram OR NEW.status NOT IN(OLD.status,'cancelled')) BEGIN SELECT RAISE(ABORT,'Approved session is immutable'); END;

CREATE TRIGGER session_materials_delete_draft BEFORE DELETE ON session_materials WHEN (SELECT status FROM sessions WHERE session_id=OLD.session_id)<>'draft' BEGIN SELECT RAISE(ABORT,'Session is locked'); END;

CREATE TRIGGER session_materials_insert_draft BEFORE INSERT ON session_materials WHEN (SELECT status FROM sessions WHERE session_id=NEW.session_id)<>'draft' BEGIN SELECT RAISE(ABORT,'Session is locked'); END;

CREATE TRIGGER session_materials_update_draft BEFORE UPDATE ON session_materials WHEN (SELECT status FROM sessions WHERE session_id=NEW.session_id)<>'draft' BEGIN SELECT RAISE(ABORT,'Session is locked'); END;

CREATE TRIGGER session_no_delete BEFORE DELETE ON sessions WHEN OLD.status<>'draft' BEGIN SELECT RAISE(ABORT,'Archive approved sessions'); END;

CREATE TRIGGER session_no_void_paid BEFORE UPDATE OF status ON sessions WHEN NEW.status='cancelled' AND EXISTS(SELECT 1 FROM charges c JOIN payment_allocations a ON a.charge_id=c.charge_id JOIN payments p ON p.payment_id=a.payment_id WHERE c.session_id=OLD.session_id AND p.voided_at IS NULL) BEGIN SELECT RAISE(ABORT,'Void related payments before cancelling'); END;

CREATE TRIGGER session_patient_fixed BEFORE UPDATE OF patient_id ON sessions WHEN OLD.patient_id<>NEW.patient_id BEGIN SELECT RAISE(ABORT,'Patient link is immutable'); END;

CREATE TRIGGER session_procedure_fixed BEFORE UPDATE OF procedure_id ON sessions WHEN OLD.status<>'draft' AND NEW.procedure_id IS NOT OLD.procedure_id BEGIN SELECT RAISE(ABORT,'Historical procedure is immutable'); END;

CREATE TRIGGER stock_usage_delete AFTER DELETE ON session_materials WHEN OLD.quantity>0 BEGIN UPDATE material_inventory SET stock_milli=stock_milli+OLD.quantity,revision=revision+1 WHERE material_id=OLD.material_id; END;

CREATE TRIGGER stock_usage_insert AFTER INSERT ON session_materials WHEN NEW.quantity>0 BEGIN UPDATE material_inventory SET stock_milli=stock_milli-NEW.quantity,revision=revision+1 WHERE material_id=NEW.material_id; END;

CREATE TRIGGER stock_usage_update AFTER UPDATE OF quantity ON session_materials WHEN NEW.quantity<>OLD.quantity BEGIN UPDATE material_inventory SET stock_milli=stock_milli+OLD.quantity-NEW.quantity,revision=revision+1 WHERE material_id=NEW.material_id; END;

CREATE TRIGGER usage_material_fixed BEFORE UPDATE OF material_id ON session_materials WHEN NEW.material_id<>OLD.material_id BEGIN SELECT RAISE(ABORT,'Material link is immutable'); END;

CREATE TRIGGER usage_session_fixed BEFORE UPDATE OF session_id ON session_materials WHEN OLD.session_id<>NEW.session_id BEGIN SELECT RAISE(ABORT,'Usage cannot move between sessions'); END;

CREATE TRIGGER version_immutable BEFORE UPDATE ON material_versions BEGIN SELECT RAISE(ABORT,'Material versions are immutable'); END;

CREATE TRIGGER version_no_delete BEFORE DELETE ON material_versions BEGIN SELECT RAISE(ABORT,'Archive the material instead'); END;
COMMIT;
