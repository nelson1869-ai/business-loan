import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/admin_assistant_repository.dart';

class AdminAssistantPage extends ConsumerStatefulWidget {
  const AdminAssistantPage({super.key});

  @override
  ConsumerState<AdminAssistantPage> createState() => _AdminAssistantPageState();
}

class _AdminAssistantPageState extends ConsumerState<AdminAssistantPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[
    const _ChatMessage(
      text:
          'Ask about collections, unpaid installments, overdue accounts, or portfolio performance.',
      isUser: false,
    ),
  ];
  bool _waiting = false;
  String? _lastQuestion;
  String? _activeBorrowerId;
  String? _activeBorrowerName;

  static const _suggestions = <String>[
    'How much was collected this month?',
    'Who has not paid today?',
    'Who is due tomorrow?',
    'Show overdue accounts',
    'Summarize portfolio performance',
    'List borrowers',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send([
    String? suggested,
    String? selectedBorrowerId,
    bool suppressUserMessage = false,
    int offset = 0,
  ]) async {
    final text = (suggested ?? _controller.text).trim();
    if (text.length < 2 || _waiting) return;
    final contextualBorrowerId =
        selectedBorrowerId ??
        (_refersToCurrentBorrower(text) ? _activeBorrowerId : null);
    _controller.clear();
    setState(() {
      _waiting = true;
      _lastQuestion = text;
      if (selectedBorrowerId == null && !suppressUserMessage && offset == 0) {
        _messages.add(_ChatMessage(text: text, isUser: true));
      }
    });
    _scrollToLatest();
    try {
      final reply = await ref
          .read(adminAssistantRepositoryProvider)
          .ask(text, selectedBorrowerId: contextualBorrowerId, offset: offset);
      if (!mounted) return;
      setState(() {
        if (offset > 0) {
          final index = _messages.lastIndexWhere(
            (message) =>
                message.reply != null && message.reply!.intent == reply.intent,
          );
          if (index >= 0) {
            _messages[index] = _ChatMessage.fromReply(
              _messages[index].reply!.mergePage(reply),
            );
          } else {
            _messages.add(_ChatMessage.fromReply(reply));
          }
        } else {
          _messages.add(_ChatMessage.fromReply(reply));
        }
      });
      _scrollToLatest();
    } on AdminAssistantRequestException catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: error.message,
            isUser: false,
            isError: error.isError,
          ),
        );
      });
      _scrollToLatest();
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _messages.add(
          const _ChatMessage(
            text: 'The assistant returned an invalid response. Please retry.',
            isUser: false,
            isError: true,
          ),
        );
      });
      _scrollToLatest();
    } finally {
      if (mounted) setState(() => _waiting = false);
    }
  }

  bool _refersToCurrentBorrower(String text) {
    final normalized = text.toLowerCase();
    return RegExp(
      r'\b(they|them|their|he|him|his|she|her)\b|'
      r'\b(this|that|the)\s+borrower\b',
    ).hasMatch(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Assistant'),
        actions: [
          IconButton(
            tooltip: 'Clear conversation',
            onPressed: _waiting
                ? null
                : () => setState(() {
                    _activeBorrowerId = null;
                    _activeBorrowerName = null;
                    _messages
                      ..clear()
                      ..add(
                        const _ChatMessage(
                          text:
                              'Conversation cleared. What would you like to know?',
                          isUser: false,
                        ),
                      );
                  }),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: _messages.length + (_waiting ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const _WaitingBubble();
                }
                return _MessageBubble(
                  message: _messages[index],
                  onSelectBorrower: (option) {
                    final question = _lastQuestion;
                    if (question != null) {
                      _activeBorrowerId = option.borrowerId;
                      _activeBorrowerName = option.displayName;
                      _send(question, option.borrowerId);
                    }
                  },
                  onRetry: () {
                    final question = _lastQuestion;
                    if (question != null) _send(question, null, true);
                  },
                  onLoadMore: () {
                    final question = _lastQuestion;
                    final nextOffset = _messages[index].reply?.nextOffset;
                    if (question != null && nextOffset != null) {
                      _send(question, null, true, nextOffset);
                    }
                  },
                );
              },
            ),
          ),
          if (_activeBorrowerName case final borrowerName?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  avatar: const Icon(Icons.person_outline, size: 18),
                  label: Text('Asking about $borrowerName'),
                  deleteIcon: const Tooltip(
                    message: 'Clear borrower context',
                    child: Icon(Icons.close, size: 18),
                  ),
                  onDeleted: _waiting
                      ? null
                      : () => setState(() {
                          _activeBorrowerId = null;
                          _activeBorrowerName = null;
                        }),
                ),
              ),
            ),
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) => ActionChip(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.65),
                ),
                label: Text(
                  _suggestions[index],
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                onPressed: _waiting ? null : () => _send(_suggestions[index]),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: TextField(
                controller: _controller,
                enabled: !_waiting,
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Ask about the business…',
                  counterText: '',
                  prefixIcon: const Icon(Icons.auto_awesome_outlined),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(5),
                    child: IconButton.filled(
                      tooltip: 'Send',
                      onPressed: _waiting ? null : _send,
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.reply,
    this.isError = false,
  });

  factory _ChatMessage.fromReply(AdminAssistantReply reply) =>
      _ChatMessage(text: reply.answer, isUser: false, reply: reply);

  final String text;
  final bool isUser;
  final AdminAssistantReply? reply;
  final bool isError;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onSelectBorrower,
    required this.onRetry,
    required this.onLoadMore,
  });

  final _ChatMessage message;
  final ValueChanged<BorrowerClarificationOption> onSelectBorrower;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final reply = message.reply;
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: message.isUser ? 0.82 : 1,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          margin: const EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.symmetric(
            horizontal: message.isUser ? 16 : 18,
            vertical: message.isUser ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: message.isUser
                ? colors.primaryContainer
                : message.isError
                ? colors.errorContainer.withValues(alpha: 0.55)
                : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(message.isUser ? 20 : 18),
            border: message.isUser
                ? null
                : Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.25),
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isError) ...[
                    Icon(
                      Icons.info_outline_rounded,
                      size: 19,
                      color: colors.error,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      _formatDisplayText(message.text),
                      style: textTheme.bodyLarge?.copyWith(
                        color: message.isUser
                            ? colors.onPrimaryContainer
                            : message.isError
                            ? colors.onErrorContainer
                            : colors.onSurface,
                        height: 1.4,
                        fontWeight: reply == null ? null : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (reply != null && reply.metrics.isNotEmpty) ...[
                const SizedBox(height: 14),
                _MetricGrid(reply: reply),
              ],
              if (reply != null && reply.clarification.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...reply.clarification.map(
                  (option) => Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(option.displayName),
                      subtitle: Text(option.maskedReference),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onSelectBorrower(option),
                    ),
                  ),
                ),
              ],
              if (reply != null && reply.records.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...reply.records.map(
                  (record) => Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(record.borrowerName),
                      subtitle: Text(_recordSubtitle(record, reply.currency)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push('/borrowers/${record.borrowerId}'),
                    ),
                  ),
                ),
              ],
              if (reply != null) ...[
                const SizedBox(height: 14),
                Divider(
                  height: 1,
                  color: colors.outlineVariant.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Icon(
                      reply.answerSource == 'offline'
                          ? Icons.cloud_off_outlined
                          : reply.aiUsed
                          ? Icons.auto_awesome
                          : Icons.verified_outlined,
                      size: 17,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        reply.answerSource == 'offline'
                            ? 'Offline local answer'
                            : reply.aiUsed
                            ? 'AI-enhanced answer'
                            : 'Verified local answer',
                        style: textTheme.labelLarge?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (reply.hasMore)
                      Text(
                        '${reply.records.length} of '
                        '${reply.totalMatchingCount}',
                        style: textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                if (reply.lastSyncedAt case final syncedAt?)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Last synchronized: ${syncedAt.toLocal()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (reply.answerSource == 'offline')
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry server connection'),
                  ),
                if (reply.hasMore)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onLoadMore,
                      icon: const Icon(Icons.expand_more),
                      label: Text(
                        'Load more · ${reply.records.length} of '
                        '${reply.totalMatchingCount}',
                      ),
                    ),
                  ),
                Text(
                  '${reply.source} · As of ${reply.asOf}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (reply.intentConfidence > 0)
                  Text(
                    'Intent match: ${reply.intentConfidence}%',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _currencySymbol(String currency) =>
      currency.toUpperCase() == 'PHP' ? '₱' : '$currency ';

  static String _recordSubtitle(AdminAssistantRecord record, String currency) {
    if (record.recordType == 'payment') {
      final amount = record.amountPaid;
      final date = record.effectiveDate;
      return [
        // ignore: use_null_aware_elements
        if (amount != null) '${_currencySymbol(currency)}$amount paid',
        // ignore: use_null_aware_elements
        if (date != null) date,
        record.status,
      ].where((value) => value.isNotEmpty).join(' · ');
    }
    if (record.recordType == 'borrower') return record.status;
    if (record.dueDate != null) {
      return '${_currencySymbol(currency)}${record.amountDue} due '
          '${record.dueDate} · ${record.status}';
    }
    return record.status;
  }

  static String _formatDisplayText(String text) {
    return text.replaceAllMapped(RegExp(r'\bPHP\s+(\d+(?:\.\d+)?)'), (match) {
      final value = double.tryParse(match.group(1) ?? '');
      if (value == null) return match.group(0) ?? '';
      final fixed = value.toStringAsFixed(2).split('.');
      final whole = fixed.first.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (group) => '${group[1]},',
      );
      return '₱$whole.${fixed.last}';
    });
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.reply});

  final AdminAssistantReply reply;

  static const _labels = <String, String>{
    'collections': 'Collections',
    'interestEarned': 'Interest earned',
    'principalCollected': 'Principal collected',
    'outstandingBalance': 'Outstanding',
    'originalPrincipal': 'Original principal',
    'totalPaid': 'Total paid',
    'nextAmountDue': 'Next payment',
    'activeLoans': 'Active loans',
    'activeLoanCount': 'Active loans',
    'overdueLoans': 'Overdue loans',
    'overdueInstallments': 'Overdue',
    'recordCount': 'Records',
  };

  static const _moneyKeys = <String>{
    'collections',
    'interestEarned',
    'principalCollected',
    'outstandingBalance',
    'originalPrincipal',
    'totalPaid',
    'nextAmountDue',
  };

  @override
  Widget build(BuildContext context) {
    final entries = reply.metrics.entries
        .where((entry) => _labels.containsKey(entry.key))
        .take(4)
        .toList(growable: false);
    if (entries.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entries
              .map((entry) {
                final value = _moneyKeys.contains(entry.key)
                    ? _MessageBubble._formatDisplayText(
                        '${reply.currency} ${entry.value}',
                      )
                    : entry.value;
                return Container(
                  width: width,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: 0.55,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _labels[entry.key]!,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}

class _WaitingBubble extends StatelessWidget {
  const _WaitingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Card(
        child: SizedBox(
          width: 320,
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Checking verified records… Free AI may take a minute.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
