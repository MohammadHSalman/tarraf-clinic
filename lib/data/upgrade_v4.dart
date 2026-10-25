import 'package:sqflite_common/sqlite_api.dart';
import 'schema.dart';

/// Called within sqflite's onCreate/onUpgrade transaction. No historical rewrites.
class UpgradeV4 {
  static Future<void> run(DatabaseExecutor d) async {
    final pk = ClinicSchema.uuid;
    for (final sql in [
      'ALTER TABLE patients ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN(0,1))',
      'ALTER TABLE patients ADD COLUMN is_hidden INTEGER NOT NULL DEFAULT 0 CHECK(is_hidden IN(0,1))',
      'ALTER TABLE materials ADD COLUMN is_hidden INTEGER NOT NULL DEFAULT 0 CHECK(is_hidden IN(0,1))',
      "ALTER TABLE material_versions ADD COLUMN standard_unit TEXT CHECK(standard_unit IN('Unit','CC','Syringe','Vial','Box'))",
      'ALTER TABLE material_versions ADD COLUMN fx_rate_micros INTEGER CHECK(fx_rate_micros>0)',
      'ALTER TABLE sessions ADD COLUMN procedure_id TEXT REFERENCES procedures(procedure_id) ON DELETE RESTRICT',
      "CREATE TABLE procedures(${pk('procedure_id')},name_ar TEXT NOT NULL,name_en TEXT NOT NULL,category TEXT NOT NULL CHECK(category IN('surgery','consultation','injection')),is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN(0,1)),is_hidden INTEGER NOT NULL DEFAULT 0 CHECK(is_hidden IN(0,1))) STRICT",
      "CREATE TABLE material_inventory(material_id TEXT PRIMARY KEY REFERENCES materials(material_id) ON DELETE RESTRICT,name_ar TEXT NOT NULL DEFAULT '',name_en TEXT NOT NULL DEFAULT '',stock_milli INTEGER NOT NULL DEFAULT 0 CHECK(stock_milli BETWEEN 0 AND 1000000000),revision INTEGER NOT NULL DEFAULT 0) STRICT",
      'CREATE TABLE stock_movements(${pk('movement_id')},material_id TEXT NOT NULL REFERENCES materials(material_id) ON DELETE RESTRICT,delta_milli INTEGER NOT NULL,at TEXT NOT NULL,reason TEXT NOT NULL) STRICT',
      "CREATE TRIGGER stock_usage_update AFTER UPDATE OF quantity ON session_materials WHEN NEW.quantity<>OLD.quantity BEGIN UPDATE material_inventory SET stock_milli=stock_milli+OLD.quantity-NEW.quantity,revision=revision+1 WHERE material_id=NEW.material_id; END",
      "CREATE TRIGGER stock_usage_insert AFTER INSERT ON session_materials WHEN NEW.quantity>0 BEGIN UPDATE material_inventory SET stock_milli=stock_milli-NEW.quantity,revision=revision+1 WHERE material_id=NEW.material_id; END",
      "CREATE TRIGGER stock_usage_delete AFTER DELETE ON session_materials WHEN OLD.quantity>0 BEGIN UPDATE material_inventory SET stock_milli=stock_milli+OLD.quantity,revision=revision+1 WHERE material_id=OLD.material_id; END",
      "CREATE TRIGGER usage_material_fixed BEFORE UPDATE OF material_id ON session_materials WHEN NEW.material_id<>OLD.material_id BEGIN SELECT RAISE(ABORT,'Material link is immutable'); END",
      "CREATE TRIGGER session_procedure_fixed BEFORE UPDATE OF procedure_id ON sessions WHEN OLD.status<>'draft' AND NEW.procedure_id IS NOT OLD.procedure_id BEGIN SELECT RAISE(ABORT,'Historical procedure is immutable'); END",
    ]) {
      await d.execute(sql);
    }
  }
}
