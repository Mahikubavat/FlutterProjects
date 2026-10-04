/// A single word token together with its character offsets in the
/// original document text. Keeping offsets lets us map matches found
/// during comparison back onto the original text for highlighting.
class TokenSpan {
  final String text;
  final int start;
  final int end;

  const TokenSpan(this.text, this.start, this.end);
}
