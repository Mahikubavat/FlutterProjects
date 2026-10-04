/// A contiguous character range in a document's text that was found to
/// match (part of) another document. Used to drive text highlighting.
class MatchRange {
  final int start;
  final int end;

  const MatchRange(this.start, this.end);

  Map<String, dynamic> toMap() => {'start': start, 'end': end};

  factory MatchRange.fromMap(Map<String, dynamic> map) =>
      MatchRange(map['start'] as int, map['end'] as int);
}
