import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/borrowers_state.dart';
import '../widgets/borrower_card.dart';

class BorrowerListPage extends ConsumerStatefulWidget {
  const BorrowerListPage({super.key});

  @override
  ConsumerState<BorrowerListPage> createState() => _BorrowerListPageState();
}

class _BorrowerListPageState extends ConsumerState<BorrowerListPage> {
  final _searchCtrl = TextEditingController();
  Timer? _debounceTimer;
  String _query = '';
  String? _statusFilter;

  static const _statuses = ['All', 'Active', 'Pending'];

  @override
  void dispose() {
    _debounceTimer?.cancel();
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
    final borrowersAsync = ref.watch(borrowersNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Borrowers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () {
              context.push('/borrowers/register');
            },
            tooltip: 'Register Borrower',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search borrowers...',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statuses.map((status) {
                  final selected =
                      _statusFilter == status ||
                      (_statusFilter == null && status == 'All');
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(status),
                      selected: selected,
                      onSelected: (_) => setState(
                        () => _statusFilter = status == 'All' ? null : status,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: borrowersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (borrowers) {
                var filtered = borrowers;
                if (_query.isNotEmpty) {
                  filtered = filtered.where((b) {
                    final n = b.fullName.toLowerCase();
                    final p = b.phone.toLowerCase();
                    final id = b.nationalId.toLowerCase();
                    return n.contains(_query) ||
                        p.contains(_query) ||
                        id.contains(_query);
                  }).toList();
                }
                if (_statusFilter != null) {
                  filtered = filtered
                      .where(
                        (b) =>
                            b.status.toLowerCase() ==
                            _statusFilter!.toLowerCase(),
                      )
                      .toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isEmpty
                          ? 'No borrowers found'
                          : 'No borrowers match "$_query"',
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final borrower = filtered[index];
                    return BorrowerCard(
                      borrower: borrower,
                      onTap: () => context.go(
                        '/borrowers/${borrower.id}',
                        extra: borrower,
                      ),
                      onEdit: () =>
                          context.go('/borrowers/register', extra: borrower),
                      onDelete: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Borrower'),
                            content: Text(
                              'Are you sure you want to delete ${borrower.fullName}? '
                              'This action cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          await ref
                              .read(borrowersNotifierProvider.notifier)
                              .deleteBorrower(borrower.id);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/borrowers/register');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
