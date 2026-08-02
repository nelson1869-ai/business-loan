import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/loan_policy_repository.dart';
import '../domain/loan_policy.dart';

final loanPoliciesProvider = FutureProvider.autoDispose<List<LoanPolicy>>((
  ref,
) {
  return ref.watch(loanPolicyRepositoryProvider).list();
});
