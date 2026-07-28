import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/sync/sync_dependency_resolver.dart';

Map<String, dynamic> _row(
  String id,
  String type, {
  List<String> dependencies = const [],
}) {
  return {
    'id': id,
    'transaction_uuid': 'tx-$id',
    'entity_local_id': id,
    'entity_type': type,
    'dependency_ids_json': jsonEncode(dependencies),
    'created_at': '2026-07-28T00:00:00Z',
  };
}

void main() {
  const resolver = SyncDependencyResolver();

  test('orders borrower, loan, and repayment deterministically', () {
    final plan = resolver.resolve([
      _row('payment', 'repayment', dependencies: ['loan']),
      _row('loan', 'loan', dependencies: ['borrower']),
      _row('borrower', 'borrower'),
    ]);

    expect(plan.cyclicRows, isEmpty);
    expect(plan.orderedRows.map((row) => row['id']), [
      'borrower',
      'loan',
      'payment',
    ]);
  });

  test('reports dependency cycles instead of submitting them', () {
    final plan = resolver.resolve([
      _row('first', 'borrower', dependencies: ['second']),
      _row('second', 'loan', dependencies: ['first']),
    ]);

    expect(plan.orderedRows, isEmpty);
    expect(plan.cyclicRows.map((row) => row['id']), ['first', 'second']);
  });
}
