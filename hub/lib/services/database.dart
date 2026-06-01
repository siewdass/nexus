import 'dart:io';

import 'package:sembast/sembast_io.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  bool get isOpen => _db != null;

  Future<void> init() async {
    if (isOpen) return;
    final dir = Directory('${Platform.environment['HOME'] ?? '/tmp'}/.nexus_hub/db');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _db = await databaseFactoryIo.openDatabase('${dir.path}/nexus.db');
  }

  Future<void> close() async => _db?.close();

  Database get _database {
    if (_db == null) throw StateError('DatabaseService not initialized');
    return _db!;
  }

  Future<int> create(StoreRef<int, Map<String, dynamic>> store, Map<String, dynamic> value) {
    return store.add(_database, value);
  }

  Future<Map<String, dynamic>?> read(StoreRef<int, Map<String, dynamic>> store, int id) {
    return store.record(id).get(_database);
  }

  Future<void> update(StoreRef<int, Map<String, dynamic>> store, int id, Map<String, dynamic> value) {
    return store.record(id).put(_database, value);
  }

  Future<void> delete(StoreRef<int, Map<String, dynamic>> store, int id) {
    return store.record(id).delete(_database);
  }

  Future<List<Map<String, dynamic>>> readAll(StoreRef<int, Map<String, dynamic>> store, {SortOrder? sortBy}) async {
    final finder = sortBy != null ? Finder(sortOrders: [sortBy]) : null;
    final snapshots = await store.find(_database, finder: finder);
    return snapshots.map((s) => s.value).toList();
  }

  Future<int> count(StoreRef<int, Map<String, dynamic>> store) {
    return store.count(_database);
  }

  Future<List<Map<String, dynamic>>> query(StoreRef<int, Map<String, dynamic>> store, {Finder? finder}) async {
    final snapshots = await store.find(_database, finder: finder);
    return snapshots.map((s) => s.value).toList();
  }

  Future<void> deleteAll(StoreRef<int, Map<String, dynamic>> store) {
    return store.delete(_database);
  }

  Future<List<int>> createBatch(StoreRef<int, Map<String, dynamic>> store, List<Map<String, dynamic>> values) async {
    final ids = <int>[];
    await _database.transaction((txn) async {
      for (final v in values) {
        ids.add(await store.add(txn, v));
      }
    });
    return ids;
  }
}
