/// Immutable posted journal line.
class JournalLine {
  const JournalLine({
    required this.lineNumber,
    required this.accountId,
    required this.debit,
    required this.credit,
    required this.memo,
  });

  final int lineNumber;
  final String accountId;
  final String debit;
  final String credit;
  final String memo;

  factory JournalLine.fromJson(Map<String, dynamic> json) => JournalLine(
    lineNumber: json['lineNumber'] as int,
    accountId: json['accountId'] as String,
    debit: json['debit'].toString(),
    credit: json['credit'].toString(),
    memo: json['memo'] as String,
  );
}

/// Immutable posted accounting journal.
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.currency,
    required this.postedAt,
    required this.sourceType,
    required this.sourceRecordId,
    required this.description,
    required this.status,
    required this.reconciliationStatus,
    required this.lines,
  });

  final String id;
  final String currency;
  final DateTime postedAt;
  final String sourceType;
  final String sourceRecordId;
  final String description;
  final String status;
  final String reconciliationStatus;
  final List<JournalLine> lines;

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
    id: json['id'] as String,
    currency: json['currency'] as String,
    postedAt: DateTime.parse(json['postedAt'] as String).toLocal(),
    sourceType: json['sourceType'] as String,
    sourceRecordId: json['sourceRecordId'] as String,
    description: json['description'] as String,
    status: json['status'] as String,
    reconciliationStatus: json['reconciliationStatus'] as String,
    lines: (json['lines'] as List<dynamic>)
        .map(
          (line) =>
              JournalLine.fromJson(Map<String, dynamic>.from(line as Map)),
        )
        .toList(growable: false),
  );
}
