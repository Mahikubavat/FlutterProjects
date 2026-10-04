import 'document_page.dart';

class DocumentExtraction {
  final String rawText;
  final String cleanedText;
  final List<DocumentPage> pages;
  final List<String> errors;

  const DocumentExtraction({
    required this.rawText,
    required this.cleanedText,
    required this.pages,
    this.errors = const [],
  });
}
