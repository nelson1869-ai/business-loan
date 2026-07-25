import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/business_setting_repository.dart';
import '../domain/business_setting.dart';

final businessSettingProvider = FutureProvider.autoDispose<BusinessSetting>((
  ref,
) {
  return ref.watch(businessSettingRepositoryProvider).load();
});
