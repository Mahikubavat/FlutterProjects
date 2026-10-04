/// Text extracted from one source page, retaining both provider output and
/// the lightly normalized text used by similarity analysis.
class DocumentPage {
  final int pageNumber;
  final String rawText;
  final String cleanedText;
  final String source;
  final String? error;

  const DocumentPage({
    required this.pageNumber,
    required this.rawText,
    required this.cleanedText,
    required this.source,
    this.error,
  });

  Map<String, dynamic> toMap() => {
        'pageNumber': pageNumber,
        'rawText': rawText,
        'cleanedText': cleanedText,
        'source': source,
        'error': error,
      };

  factory DocumentPage.fromMap(Map<String, dynamic> map) => DocumentPage(
        pageNumber: map['pageNumber'] as int,
        rawText: map['rawText'] as String,
        cleanedText: map['cleanedText'] as String,
        source: map['source'] as String,
        error: map['error'] as String?,
      );
}
