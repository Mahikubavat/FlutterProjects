import 'package:flutter/material.dart';
import 'similarity_engine.dart';

class ComparisonScreen extends StatelessWidget {
  final String text1;
  final String text2;
  final Set<String> matchingWords;
  final double score;

  const ComparisonScreen({
    super.key,
    required this.text1,
    required this.text2,
    required this.matchingWords,
    required this.score,
  });

  List<InlineSpan> _buildWordSpans(String fullText) {
    List<InlineSpan> spans = [];

    // Regex splits text into words/numbers (\w+), whitespace (\s+), or punctuation ([^\w\s]+)
    final RegExp tokenRegex = RegExp(r'(\w+|\s+|[^\w\s]+)');
    final matches = tokenRegex.allMatches(fullText);

    for (final match in matches) {
      String token = match.group(0)!;
      String normalizedToken = SimilarityEngine.normalizeWord(token);

      bool isMatch = normalizedToken.isNotEmpty && matchingWords.contains(normalizedToken);

      spans.add(
        TextSpan(
          text: token,
          style: TextStyle(
            backgroundColor: isMatch ? Colors.yellow.shade400 : Colors.transparent,
            color: isMatch ? Colors.black : Colors.black87,
            fontWeight: isMatch ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text("Match Details (${score.toStringAsFixed(1)}% Similarity)"),
        elevation: 2,
      ),
      body: Row(
        children: [
          Expanded(child: _buildDocumentView("Document 1", text1)),
          const VerticalDivider(width: 2, color: Colors.grey),
          Expanded(child: _buildDocumentView("Document 2", text2)),
        ],
      ),
    );
  }

  Widget _buildDocumentView(String title, String text) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          color: Colors.blueGrey.shade800,
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.black87,
                  ),
                  children: _buildWordSpans(text),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}