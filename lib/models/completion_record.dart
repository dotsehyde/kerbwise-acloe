class CompletionRecord {
  const CompletionRecord({
    required this.id,
    required this.cashPence,
    required this.key,
    required this.queuedAt,
    this.reviewReason,
    this.expectedCashPence,
  });

  factory CompletionRecord.fromJson(Map<String, dynamic> json) =>
      CompletionRecord(
        id: json['id'] as int,
        cashPence: json['cashPence'] as int,
        key: json['key'] as String,
        queuedAt: DateTime.tryParse(json['queuedAt'] as String? ?? ''),
        reviewReason: json['reviewReason'] as String?,
        expectedCashPence: json['expectedCashPence'] as int?,
      );

  final int id;
  final int cashPence;
  final String key;
  final DateTime? queuedAt;
  final String? reviewReason;
  final int? expectedCashPence;

  bool get needsReview => reviewReason != null;

  CompletionRecord forReview(String reason, {int? expectedCashPence}) =>
      CompletionRecord(
        id: id,
        cashPence: cashPence,
        key: key,
        queuedAt: queuedAt,
        reviewReason: reason,
        expectedCashPence: expectedCashPence,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'cashPence': cashPence,
    'key': key,
    'queuedAt': queuedAt?.toIso8601String(),
    'reviewReason': reviewReason,
    'expectedCashPence': expectedCashPence,
  };
}
