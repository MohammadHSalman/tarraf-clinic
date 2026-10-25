import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tarraf_clinic/data/clinic_repository.dart';
import 'data_model_test.dart' as fixtures;

void requireNativeQueryArgs(List<Object?>? args) {
  if (args?.contains(null) ?? false) {
    throw ArgumentError('SQLCipher Android query bind value is null');
  }
}

class NativeQueryDatabase extends Fake implements Database {
  final Database target;
  NativeQueryDatabase(this.target);
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    requireNativeQueryArgs(whereArgs);
    return target.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    requireNativeQueryArgs(arguments);
    return target.rawQuery(sql, arguments);
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) => target.transaction(
    (t) => action(NativeQueryTransaction(t)),
    exclusive: exclusive,
  );
}

class NativeQueryTransaction extends Fake implements Transaction {
  final Transaction target;
  NativeQueryTransaction(this.target);
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    requireNativeQueryArgs(whereArgs);
    return target.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    requireNativeQueryArgs(arguments);
    return target.rawQuery(sql, arguments);
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) =>
      target.rawUpdate(sql, arguments);
  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) => target.insert(
    table,
    values,
    nullColumnHack: nullColumnHack,
    conflictAlgorithm: conflictAlgorithm,
  );
  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) => target.update(
    table,
    values,
    where: where,
    whereArgs: whereArgs,
    conflictAlgorithm: conflictAlgorithm,
  );
  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) =>
      target.delete(table, where: where, whereArgs: whereArgs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test(
    'Android query binding: global settings and no-batch point edits never bind null',
    () async {
      final repo = await fixtures.repository();
      addTearDown(repo.db.close);
      await repo.document('settings', {'ar': true, 'bio': false});
      final native = ClinicRepository(NativeQueryDatabase(repo.db), repo.box);
      expect((await native.documents('settings')).single['ar'], true);
      final (_, sid, vid) = await fixtures.draft(repo);
      for (final quantity in [1250, 750]) {
        await native.savePoint(
          sessionId: sid,
          revision: await fixtures.revision(repo, sid),
          versionId: vid,
          milliQuantity: quantity,
          x: .4,
          y: .3,
        );
      }
      final usage = (await repo.db.query('session_materials')).single;
      expect(usage['batch_id'], isNull);
      expect(usage['quantity'], 2000);
      expect(usage['approved_cost_minor'], 400);
      final point = (await repo.points(sid)).first;
      await native.deletePoint(
        point['point_id'] as String,
        sid,
        await fixtures.revision(repo, sid),
      );
      expect(
        (await repo.db.query('session_materials')).single['quantity'],
        750,
      );
    },
  );
}
