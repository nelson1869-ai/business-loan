import 'dart:convert';

/// Deterministic queue plan containing runnable rows and dependency cycles.
class SyncDependencyPlan {
  const SyncDependencyPlan({
    required this.orderedRows,
    required this.cyclicRows,
  });

  final List<Map<String, dynamic>> orderedRows;
  final List<Map<String, dynamic>> cyclicRows;
}

/// Orders queued mutations without depending on SQLite, Dio, or Flutter.
class SyncDependencyResolver {
  const SyncDependencyResolver();

  /// Produces borrower -> dependent financial-event ordering using Kahn's
  /// algorithm. Rows in a dependency cycle are reported and never submitted.
  SyncDependencyPlan resolve(List<Map<String, dynamic>> rows) {
    final itemMap = <String, Map<String, dynamic>>{};
    final transactionMap = <String, Map<String, dynamic>>{};
    final localIdMap = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      final id = row['id'] as String;
      itemMap[id] = row;
      transactionMap[row['transaction_uuid'] as String] = row;
      final localId = row['entity_local_id'] as String?;
      if (localId != null && localId.isNotEmpty) {
        localIdMap[localId] = row;
      }
    }

    final inDegree = {for (final id in itemMap.keys) id: 0};
    final graph = {for (final id in itemMap.keys) id: <String>[]};

    for (final row in rows) {
      final childId = row['id'] as String;
      for (final dependency in _dependencies(row['dependency_ids_json'])) {
        final parent =
            itemMap[dependency] ??
            transactionMap[dependency] ??
            localIdMap[dependency];
        final parentId = parent?['id'] as String?;
        if (parentId == null || parentId == childId) {
          continue;
        }
        graph[parentId]!.add(childId);
        inDegree[childId] = inDegree[childId]! + 1;
      }
    }

    final ready = rows.where((row) => inDegree[row['id']] == 0).toList()
      ..sort(_compareRows);
    final ordered = <Map<String, dynamic>>[];
    while (ready.isNotEmpty) {
      final row = ready.removeAt(0);
      ordered.add(row);
      for (final childId in graph[row['id']]!) {
        inDegree[childId] = inDegree[childId]! - 1;
        if (inDegree[childId] == 0) {
          ready.add(itemMap[childId]!);
          ready.sort(_compareRows);
        }
      }
    }

    final orderedIds = ordered.map((row) => row['id']).toSet();
    final cyclic = rows.where((row) => !orderedIds.contains(row['id'])).toList()
      ..sort(_compareRows);
    return SyncDependencyPlan(orderedRows: ordered, cyclicRows: cyclic);
  }

  List<String> _dependencies(Object? encoded) {
    if (encoded is! String || encoded.isEmpty) {
      return const [];
    }
    try {
      return (jsonDecode(encoded) as List<dynamic>)
          .whereType<String>()
          .toList();
    } on FormatException {
      return const [];
    }
  }

  static int _compareRows(
    Map<String, dynamic> first,
    Map<String, dynamic> second,
  ) {
    final priority = _priority(
      first['entity_type'] as String? ?? '',
    ).compareTo(_priority(second['entity_type'] as String? ?? ''));
    if (priority != 0) {
      return priority;
    }
    final created = (first['created_at'] as String? ?? '').compareTo(
      second['created_at'] as String? ?? '',
    );
    if (created != 0) {
      return created;
    }
    return (first['transaction_uuid'] as String).compareTo(
      second['transaction_uuid'] as String,
    );
  }

  static int _priority(String entityType) {
    return switch (entityType) {
      'borrower' => 10,
      'guarantor' || 'emergency_contact' || 'borrower_note' => 20,
      'loan' => 30,
      'loan_schedule' => 40,
      'repayment' || 'collection' => 50,
      'document' => 60,
      _ => 99,
    };
  }
}
