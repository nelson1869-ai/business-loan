import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../security/encryption_service.dart';
import 'database_provider.dart';
import 'database_service.dart';

/// Small encrypted JSON cache used by server-backed reference data.
class LocalJsonCache {
  const LocalJsonCache(this._databaseService, this._encryption);

  final DatabaseService _databaseService;
  final EncryptionService _encryption;

  Future<Object?> read(String key) async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'local_json_cache',
      columns: ['value_json'],
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final encrypted = rows.first['value_json'] as String;
    return jsonDecode(await _encryption.decrypt(encrypted));
  }

  Future<void> write(String key, Object? value) async {
    final db = await _databaseService.database;
    await db.insert('local_json_cache', {
      'cache_key': key,
      'value_json': await _encryption.encrypt(jsonEncode(value)),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

final localJsonCacheProvider = Provider<LocalJsonCache>((ref) {
  return LocalJsonCache(
    ref.watch(databaseServiceProvider),
    ref.watch(encryptionServiceProvider),
  );
});
