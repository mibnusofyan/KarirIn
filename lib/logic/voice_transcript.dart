/// The voice answer, built from the speech recogniser's results while the user records.
///
/// Google's recogniser on Android sends a longer answer in segments: after a pause the partial text starts over, a
/// settled segment arrives as a finished result, and the closing final result can be empty. A single result is
/// therefore only part of the answer. This keeps every finished segment and shows the live partial after them.
class VoiceTranscript {
  final _segments = <String>[];
  String _partial = '';

  /// The finished segments followed by the live partial, separated by spaces.
  String get text => [..._segments, if (_partial.isNotEmpty) _partial].join(' ');

  /// Adds one recogniser result. A partial replaces the live text of the current segment. A finished result (a settled
  /// segment or the final result of a listen) is kept; an empty one keeps the live text instead of wiping it, and one
  /// that only repeats the segment just kept is ignored.
  void add(String words, {required bool finished}) {
    final w = words.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (!finished) {
      _partial = w;
    } else if (w.isEmpty) {
      endSegment();
    } else if (_partial.isEmpty && _segments.isNotEmpty && _segments.last == w) {
      return;
    } else {
      _keep(w);
    }
  }

  /// Keeps the live text as a finished segment, for a listen that ended without a final result.
  void endSegment() => _keep(_partial);

  void clear() {
    _segments.clear();
    _partial = '';
  }

  void _keep(String segment) {
    if (segment.isNotEmpty) _segments.add(segment);
    _partial = '';
  }
}
