import 'dart:io';

import 'package:sembast/sembast_io.dart';
import 'package:uuid/uuid.dart';

final databaseService = DatabaseService._();

Filter _toFilter(Map<String, dynamic> filter) {
  if (filter.isEmpty) return Filter.and([]);
  return Filter.and([
    for (final e in filter.entries) Filter.equals(e.key, e.value),
  ]);
}

class DatabaseService {
  DatabaseService._();
  Database? _db;

  Future<void> open({
    required String path,
    String filename = 'nexus.db',
  }) async {
    final dir = Directory(path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _db = await databaseFactoryIo.openDatabase('${dir.path}/$filename');
  }

  Future<void> close() async => _db?.close();

  Future<dynamic> create(String collection, dynamic value) async {
    final store = stringMapStoreFactory.store(collection);
    if (value is List) {
      final ids = <String>[];
      for (final v in value) {
        final id = const Uuid().v4();
        v['id'] = id;
        ids.add(id);
      }
      await _db!.transaction((txn) async {
        for (var i = 0; i < value.length; i++) {
          await store.record(ids[i]).put(txn, Map<String, dynamic>.from(value[i]));
        }
      });
      return ids;
    }
    final id = const Uuid().v4();
    value['id'] = id;
    await store.record(id).put(_db!, Map<String, dynamic>.from(value));
    return id;
  }

  Future<dynamic> read(String collection, Map<String, dynamic> filter, {bool many = false}) async {
    final snapshots = await stringMapStoreFactory.store(collection).find(
      _db!,
      finder: Finder(
        filter: filter.isEmpty ? null : _toFilter(filter),
        limit: many ? null : 1,
      ),
    );
    if (many) return snapshots.map((s) => Map<String, dynamic>.from(s.value)).toList();
    return snapshots.isEmpty ? null : Map<String, dynamic>.from(snapshots.first.value);
  }

  Future<void> update(String collection, Map<String, dynamic> filter, Map<String, dynamic> data, {bool many = false}) async {
    final store = stringMapStoreFactory.store(collection);
    final items = await store.find(
      _db!,
      finder: Finder(
        filter: filter.isEmpty ? null : _toFilter(filter),
        limit: many ? null : 1,
      ),
    );
    if (items.isEmpty) return;
    if (many) {
      await _db!.transaction((txn) async {
        for (final item in items) {
          final merged = Map<String, dynamic>.from(item.value)..addAll(data);
          await store.record(item.key).put(txn, merged);
        }
      });
    } else {
      final merged = Map<String, dynamic>.from(items.first.value)..addAll(data);
      await store.record(items.first.key).put(_db!, merged);
    }
  }

  Future<void> delete(String collection, Map<String, dynamic> filter, {bool many = false}) async {
    final store = stringMapStoreFactory.store(collection);
    final items = await store.find(
      _db!,
      finder: Finder(
        filter: filter.isEmpty ? null : _toFilter(filter),
        limit: many ? null : 1,
      ),
    );
    if (items.isEmpty) return;
    if (many) {
      await _db!.transaction((txn) async {
        for (final item in items) {
          await store.record(item.key).delete(txn);
        }
      });
    } else {
      await store.record(items.first.key).delete(_db!);
    }
  }
}
