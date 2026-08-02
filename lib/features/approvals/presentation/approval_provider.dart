import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/approval_repository.dart';
import '../domain/approval_request.dart';

final approvalsProvider = FutureProvider.autoDispose<List<ApprovalRequest>>((
  ref,
) {
  return ref.watch(approvalRepositoryProvider).list();
});
