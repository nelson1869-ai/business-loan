import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../network/api_client.dart';

const _deviceIdentifierKey = 'officer_installation_id';

/// Privacy-preserving installation identifier sent with collection records.
final deviceIdentifierProvider = FutureProvider<String>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  final existing = await storage.read(key: _deviceIdentifierKey);
  if (existing != null && existing.isNotEmpty) return existing;
  final created = const Uuid().v4();
  await storage.write(key: _deviceIdentifierKey, value: created);
  return created;
});
