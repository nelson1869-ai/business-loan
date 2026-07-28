import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> _dartFiles(Directory directory) sync* {
  if (!directory.existsSync()) {
    return;
  }
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    }
  }
}

void main() {
  test('domain code does not import UI or infrastructure packages', () {
    final violations = <String>[];
    for (final file in _dartFiles(Directory('lib/features'))) {
      if (!file.path.replaceAll(r'\', '/').contains('/domain/')) {
        continue;
      }
      final source = file.readAsStringSync();
      for (final forbidden in [
        'package:flutter/material.dart',
        'package:flutter/widgets.dart',
        'package:dio/',
        'package:sqflite/',
      ]) {
        if (source.contains(forbidden)) {
          violations.add('${file.path}: $forbidden');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('presentation code does not execute raw SQL', () {
    final violations = <String>[];
    for (final file in _dartFiles(Directory('lib/features'))) {
      final path = file.path.replaceAll(r'\', '/');
      if (!path.contains('/presentation/') && !path.contains('/pages/')) {
        continue;
      }
      final source = file.readAsStringSync();
      final rawSql = RegExp(
        r'''(?:rawQuery|rawInsert|rawUpdate|rawDelete|execute)\s*\(\s*['"]'''
        r'''(?:SELECT|INSERT|UPDATE|DELETE)\s+''',
        caseSensitive: false,
      );
      if (rawSql.hasMatch(source)) {
        violations.add(file.path);
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('financial queue events cannot be coalesced', () {
    final source = File(
      'lib/core/network/offline_sync_service.dart',
    ).readAsStringSync();
    final coalescingBody = RegExp(
      r'bool _canCoalesce[\s\S]*?Future<void> enqueue',
    ).firstMatch(source)!.group(0)!;
    for (final financialType in [
      'repayment',
      'payment',
      'collection',
      'loan',
      'loan_schedule',
    ]) {
      expect(coalescingBody, isNot(contains("entityType == '$financialType'")));
    }
  });
}
