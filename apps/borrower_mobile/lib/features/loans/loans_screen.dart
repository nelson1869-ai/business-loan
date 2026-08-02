import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:borrower_mobile/features/loans/models/borrower_loan.dart';
import 'package:borrower_mobile/features/loans/providers/loans_provider.dart';
import 'package:borrower_mobile/core/widgets/route_back_navigation.dart';

class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loansListNotifierProvider);
    final currencyFormat =
        NumberFormat.currency(symbol: '₱ ', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('MMM dd, h:mm a');

    return RouteBackScope(
      fallbackLocation: '/home',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Loans'),
          leading: const RouteBackButton(
            fallbackLocation: '/home',
            tooltip: 'Back to dashboard',
          ),
        ),
        body: Column(
        children: [
          // Status Filter Bar
          _buildFilterBar(context, ref, state.selectedStatus),

          // Main Body
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref
                    .read(loansListNotifierProvider.notifier)
                    .loadLoans(isRefresh: true);
              },
              child: _buildBody(
                context,
                ref,
                state,
                currencyFormat,
                dateFormat,
                timeFormat,
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    WidgetRef ref,
    String selectedStatus,
  ) {
    final filters = [
      {'label': 'All', 'value': 'all'},
      {'label': 'Active', 'value': 'active'},
      {'label': 'Overdue', 'value': 'overdue'},
      {'label': 'Paid', 'value': 'paid'},
      {'label': 'Cancelled', 'value': 'cancelled'},
    ];

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedStatus == filter['value'];

          return ChoiceChip(
            label: Text(filter['label']!),
            selected: isSelected,
            onSelected: (_) {
              ref
                  .read(loansListNotifierProvider.notifier)
                  .setStatusFilter(filter['value']!);
            },
            selectedColor: const Color(0xFF0F172A),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF334155),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    LoansListState state,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
    DateFormat timeFormat,
  ) {
    if (state.isLoading && state.items.isEmpty) {
      return _buildSkeletonLoader();
    }

    if (state.errorMessage != null && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Failed to load loans',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    state.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(loansListNotifierProvider.notifier).loadLoans();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                const Text(
                  'No loans found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  state.selectedStatus == 'all'
                      ? 'You have no loan accounts.'
                      : 'No ${state.selectedStatus} loans match your filter.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (state.isFromCache && state.lastUpdated != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              border: Border.all(color: Colors.amber.shade400),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_off_rounded,
                    color: Colors.amber.shade800, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Offline Mode • Displaying cached loans from ${timeFormat.format(state.lastUpdated!.toLocal())}',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ...state.items.map(
          (loan) => _buildLoanCard(context, loan, currencyFormat, dateFormat),
        ),
      ],
    );
  }

  Widget _buildLoanCard(
    BuildContext context,
    BorrowerLoanListItem loan,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          context.push('/loans/${loan.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    loan.loanReference,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  _buildStatusChip(loan.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Outstanding Balance',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(loan.outstandingBalance),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Principal',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(loan.principalAmount),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        loan.nextDueDate != null
                            ? 'Next Due: ${dateFormat.format(loan.nextDueDate!)}'
                            : 'No Due Date',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Next: ${currencyFormat.format(loan.nextPaymentAmount)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              if (loan.isOverdue && loan.overdueAmount > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.red.shade700, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Overdue Amount: ${currencyFormat.format(loan.overdueAmount)}',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(
        3,
        (index) => Container(
          height: 140,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg = Colors.blue.shade50;
    Color text = Colors.blue.shade700;
    String label = status.toUpperCase();

    if (status.toLowerCase() == 'active') {
      bg = Colors.green.shade50;
      text = Colors.green.shade700;
      label = 'ACTIVE';
    } else if (status.toLowerCase() == 'overdue') {
      bg = Colors.red.shade50;
      text = Colors.red.shade700;
      label = 'OVERDUE';
    } else if (status.toLowerCase() == 'paid') {
      bg = Colors.purple.shade50;
      text = Colors.purple.shade700;
      label = 'PAID';
    } else if (status.toLowerCase() == 'cancelled') {
      bg = Colors.grey.shade100;
      text = Colors.grey.shade700;
      label = 'CANCELLED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
