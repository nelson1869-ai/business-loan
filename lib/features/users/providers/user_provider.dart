import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_repository.dart';
import '../domain/app_user.dart';

final usersProvider = FutureProvider.autoDispose<List<AppUser>>((ref) {
  return ref.watch(userRepositoryProvider).load();
});
