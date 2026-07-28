/// Validated, read-only AI explanation returned by the backend.
class LoanExplanation {
  const LoanExplanation({
    required this.summary,
    required this.keyPoints,
    required this.generatedAt,
    required this.model,
    required this.disclaimer,
  });

  final String summary;
  final List<String> keyPoints;
  final DateTime generatedAt;
  final String model;
  final String disclaimer;

  factory LoanExplanation.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'];
    final rawPoints = json['keyPoints'];
    final generatedAt = DateTime.tryParse(
      json['generatedAt']?.toString() ?? '',
    );
    if (summary is! String ||
        summary.trim().isEmpty ||
        rawPoints is! List<dynamic> ||
        generatedAt == null) {
      throw const FormatException('Invalid loan explanation response');
    }
    final points = rawPoints
        .whereType<String>()
        .map((point) => point.trim())
        .where((point) => point.isNotEmpty)
        .toList(growable: false);
    if (points.isEmpty) {
      throw const FormatException('Loan explanation has no key points');
    }
    return LoanExplanation(
      summary: summary.trim(),
      keyPoints: points,
      generatedAt: generatedAt,
      model: json['model']?.toString() ?? '',
      disclaimer:
          json['disclaimer']?.toString() ??
          'AI-generated explanation. Verify against the official loan schedule.',
    );
  }
}
