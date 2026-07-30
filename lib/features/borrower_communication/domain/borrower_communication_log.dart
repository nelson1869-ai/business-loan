enum BorrowerCommunicationStatus {
  openedInSms,
  confirmedSent,
  notSent,
  openedShareSheet,
}

class BorrowerCommunicationLog {
  const BorrowerCommunicationLog({
    required this.id,
    required this.borrowerId,
    required this.messageType,
    required this.channel,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.loanId,
    this.paymentId,
  });

  final String id;
  final String borrowerId;
  final String? loanId;
  final String? paymentId;
  final String messageType;
  final String channel;
  final BorrowerCommunicationStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
}
