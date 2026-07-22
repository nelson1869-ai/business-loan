import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import 'providers/loans_provider.dart';

class LoansListPage extends ConsumerWidget {
  const LoansListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allLoans = ref.watch(allLoansProvider);
    final theme = Theme.of(context);

    final queryStatus = GoRouterState.of(context).uri.queryParameters['status'];
    final initialTab = _tabIndex(queryStatus);

    return Scaffold(
      appBar: AppBar(title: const Text('Loans Portfolio')),
      body: allLoans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load loans.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.invalidate(allLoansProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (items) => _LoansListView(
          items: items,
          initialTab: initialTab,
          theme: theme,
          ref: ref,
        ),
      ),
    );
  }

  int _tabIndex(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return 1;
      case 'overdue':
        return 2;
      case 'paid':
        return 3;
      default:
        return 0;
    }
  }
}

const _tabs = ['All', 'Active', 'Overdue', 'Paid'];

class _LoansListView extends StatefulWidget {
  const _LoansListView({
    required this.items,
    required this.initialTab,
    required this.theme,
    required this.ref,
  });

  final List<LoanWithBorrower> items;
  final int initialTab;
  final ThemeData theme;
  final WidgetRef ref;

  @override
  State<_LoansListView> createState() => _LoansListViewState();
}

class _LoansListViewState extends State<_LoansListView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  Timer? _debounceTimer;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _query = value.trim().toLowerCase());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by Borrower or Loan ID',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        TabBar(
          controller: _tabController,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _tabs.map((tab) {
              final filtered = _filtered(widget.items, tab);
              return RefreshIndicator(
                onRefresh: () async => widget.ref.invalidate(allLoansProvider),
                child: filtered.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(
                            height: 200,
                            child: Center(
                              child: Text(
                                _query.isNotEmpty
                                    ? 'No matching loans.'
                                    : 'No ${tab.toLowerCase()} loans.',
                                style: TextStyle(
                                  color: widget.theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) =>
                            _LoanTile(item: filtered[i], theme: widget.theme),
                      ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<LoanWithBorrower> _filtered(List<LoanWithBorrower> items, String tab) {
    var result = items;
    if (_query.isNotEmpty) {
      result = result.where((e) {
        final name = e.borrowerName.toLowerCase();
        final loanId = e.loan.id.toLowerCase();
        final amount = e.loan.outstandingPrincipal.toLowerCase();
        return name.contains(_query) ||
            loanId.contains(_query) ||
            amount.contains(_query);
      }).toList();
    }
    switch (tab) {
      case 'Active':
        return result.where((e) => e.loan.status == 'Active').toList();
      case 'Overdue':
        return result.where((e) => e.loan.status == 'Overdue').toList();
      case 'Paid':
        return result.where((e) => e.loan.status == 'Paid').toList();
      default:
        return result;
    }
  }
}

class _LoanTile extends StatelessWidget {
  const _LoanTile({required this.item, required this.theme});

  final LoanWithBorrower item;
  final ThemeData theme;

  String _displayTitle(LoanWithBorrower item) {
    final name = item.borrowerName.trim();
    if (name.contains('-') && name.length >= 20) {
      final shortId = item.loan.id.length >= 8
          ? item.loan.id.substring(0, 8)
          : item.loan.id;
      return 'Loan #$shortId';
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final loan = item.loan;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/loans/${loan.id}'),
        leading: CircleAvatar(
          backgroundColor: _statusColor(loan.status).withValues(alpha: 0.12),
          child: Icon(
            _statusIcon(loan.status),
            color: _statusColor(loan.status),
            size: 20,
          ),
        ),
        title: Text(
          _displayTitle(item),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${formatCurrency(loan.outstandingPrincipal)} outstanding',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: _StatusBadge(status: loan.status),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Active':
        return const Color(0xFF10B981);
      case 'Overdue':
        return const Color(0xFFEF4444);
      case 'Paid':
        return const Color(0xFF3B82F6);
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Active':
        return Icons.sync;
      case 'Overdue':
        return Icons.warning_amber_rounded;
      case 'Paid':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (status) {
      case 'Active':
        bg = Colors.green.withValues(alpha: 0.1);
        fg = Colors.green.shade700;
      case 'Overdue':
        bg = Colors.red.withValues(alpha: 0.1);
        fg = Colors.red.shade700;
      case 'Paid':
        bg = Colors.blue.withValues(alpha: 0.1);
        fg = Colors.blue.shade700;
      default:
        bg = Colors.grey.withValues(alpha: 0.1);
        fg = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
