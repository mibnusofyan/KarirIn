/// The voice answer, built from the speech recogniser's results while the user records.
///
/// Google's recogniser on Android sends a longer answer in segments: a settled segment arrives as a finished result and
/// the next partial starts over. A partial can come back empty in the middle of speech, a settled segment can drop the
/// first words its partial showed, and the closing final result can be empty. A single result is therefore only part
/// of the answer. This keeps every finished segment and shows the live partial after them.
class VoiceTranscript {
  final _segments = <String>[];
  String _partial = '';

  /// The recogniser cleared the live text with an empty partial. The text stays, and becomes a finished segment unless
  /// the next result continues it.
  bool _cleared = false;

  /// The finished segments followed by the live partial, separated by spaces.
  String get text => [..._segments, if (_partial.isNotEmpty) _partial].join(' ');

  /// Adds one recogniser result. A partial replaces the live text of the current segment. A finished result (a settled
  /// segment or the final result of a listen) is kept, unless the live text ends with it: then the live text is kept.
  /// Empty results never wipe text, and a finished result that only repeats the segment just kept is ignored.
  void add(String words, {required bool finished}) {
    final w = words.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (w.isEmpty) {
      if (finished) {
        endSegment();
      } else if (_partial.isNotEmpty) {
        _cleared = true;
      }
      return;
    }
    if (_cleared && !_startsWith(w, _partial)) endSegment();
    _cleared = false;
    if (!finished) {
      _partial = w;
      return;
    }
    // A listen's final result can repeat (the end of) the segment it has just settled.
    if (_partial.isEmpty && _segments.isNotEmpty && _endsWith(_segments.last, w)) return;
    // Seen on Android: partial "are sales went up by 20%", then settled "20%".
    _keep(_endsWith(_partial, w) ? _partial : w);
  }

  /// Keeps the live text as a finished segment, for a listen that ended without a final result.
  void endSegment() => _keep(_partial);

  void clear() {
    _segments.clear();
    _partial = '';
    _cleared = false;
  }

  void _keep(String segment) {
    if (segment.isNotEmpty) _segments.add(segment);
    _partial = '';
    _cleared = false;
  }

  /// Whether [text] is [words] or begins with them, as whole words and ignoring case.
  static bool _startsWith(String text, String words) {
    final t = text.toLowerCase(), w = words.toLowerCase();
    return t == w || t.startsWith('$w ');
  }

  /// Whether [text] is [words] or ends with them, as whole words and ignoring case.
  static bool _endsWith(String text, String words) {
    final t = text.toLowerCase(), w = words.toLowerCase();
    return t == w || t.endsWith(' $w');
  }
}
