import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../loans/presentation/providers/loans_provider.dart';
import '../domain/borrower_model.dart';
import '../domain/borrower_recommendation.dart';
import '../domain/borrower_recommendation_service.dart';
import 'borrowers_state.dart';

final borrowerRecommendationServiceProvider =
    Provider<BorrowerRecommendationService>((ref) {
      return const BorrowerRecommendationService();
    });

final borrowerRecommendationProvider = FutureProvider.autoDispose
    .family<BorrowerRecommendation, String>((ref, borrowerId) async {
      final service = ref.watch(borrowerRecommendationServiceProvider);

      // Watch borrowers list
      final borrowersAsync = ref.watch(borrowersNotifierProvider);
      final borrowers = borrowersAsync.valueOrNull ?? const <Borrower>[];
      final borrower = borrowers.firstWhere(
        (b) => b.id == borrowerId,
        orElse: () => Borrower(
          id: borrowerId,
          firstName: 'Borrower',
          lastName: borrowerId,
          nationalId: '',
          phone: '',
          dateOfBirth: '',
          status: 'Active',
          createdAt: '',
        ),
      );

      // Watch borrower loans
      final loansAsync = await ref.watch(
        borrowerLoansProvider(borrowerId).future,
      );

      return service.evaluate(borrower: borrower, loans: loansAsync);
    });
