import 'dart:math';

/// The voice answer, built from the speech recogniser's results while the user records.
///
/// Google's recogniser on Android sends a longer answer in segments: a settled segment arrives as a finished result and
/// the next partial starts over. A partial can come back empty in the middle of speech, a settled segment can drop the
/// first words its partial showed, and the closing final result can be empty. A single result is therefore only part
/// of the answer. This keeps every finished segment and shows the live partial after them.
///
/// One recording can span several listens: the recogniser stops by itself after a pause and is started again.
class VoiceTranscript {
  final _segments = <String>[];
  String _partial = '';

  /// The recogniser cleared the live text with an empty partial. The text stays, and becomes a finished segment unless
  /// the next result continues it.
  bool _cleared = false;

  /// Index in [_segments] of the first segment settled in the current listen.
  int _listenStart = 0;

  /// The finished segments followed by the live partial, separated by spaces.
  String get text => [..._segments, if (_partial.isNotEmpty) _partial].join(' ');

  /// Adds one recogniser result. A partial replaces the live text of the current segment, and a finished result (a
  /// settled segment or the final result of a listen) is kept in its place. Empty results never wipe text, words the
  /// recogniser drops from the start of a segment are kept, and a finished result that only repeats the segment the
  /// same listen has just settled is ignored.
  void add(String words, {required bool finished}) {
    final w = words.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (w.isEmpty) {
      if (finished) {
        _keep(_partial);
      } else if (_partial.isNotEmpty) {
        _cleared = true;
      }
      return;
    }
    if (_cleared) {
      _cleared = false;
      // After an empty partial, a result that overlaps the cleared text continues it; anything else is new speech.
      if (_overlap(_partial, w) > 0) {
        final joined = _join(_partial, w);
        if (finished) {
          _keep(joined);
        } else {
          _partial = joined;
        }
        return;
      }
      _keep(_partial);
    }
    if (!finished) {
      _partial = w;
      return;
    }
    // A listen's final result can repeat (the end of) the segment it has just settled.
    if (_partial.isEmpty && _segments.length > _listenStart && _endsWith(_segments.last, w)) return;
    // A settled result normally revises its partial, but it can also drop the partial's first words: partial "are sales
    // went up by 20%", then "20%" (seen on Android). Then the partial's end overlaps the settled result's start by more
    // words than the two share at the start, and the words before the overlap are kept.
    _keep(_overlap(_partial, w) > _sharedStart(_partial, w) ? _join(_partial, w) : w);
  }

  /// The recogniser stopped by itself and listens again: the live text becomes a finished segment.
  void newListen() {
    _keep(_partial);
    _listenStart = _segments.length;
  }

  void clear() {
    _segments.clear();
    _partial = '';
    _cleared = false;
    _listenStart = 0;
  }

  void _keep(String segment) {
    if (segment.isNotEmpty) _segments.add(segment);
    _partial = '';
    _cleared = false;
  }

  /// [later] after the words of [earlier] that come before their overlap: "are sales went up" and "went up by 20%" give
  /// "are sales went up by 20%".
  static String _join(String earlier, String later) {
    final head = earlier.split(' ');
    return [...head.take(head.length - _overlap(earlier, later)), later].join(' ');
  }

  /// How many words at the end of [earlier] equal the words at the start of [later], ignoring case.
  static int _overlap(String earlier, String later) {
    final a = _words(earlier), b = _words(later);
    for (var n = min(a.length, b.length); n > 0; n--) {
      var match = true;
      for (var i = 0; i < n && match; i++) {
        match = a[a.length - n + i] == b[i];
      }
      if (match) return n;
    }
    return 0;
  }

  /// How many words [a] and [b] share at the start, ignoring case.
  static int _sharedStart(String a, String b) {
    final x = _words(a), y = _words(b);
    var n = 0;
    while (n < x.length && n < y.length && x[n] == y[n]) {
      n++;
    }
    return n;
  }

  static List<String> _words(String s) => s.isEmpty ? const [] : s.toLowerCase().split(' ');

  /// Whether [text] is [words] or ends with them, as whole words and ignoring case.
  static bool _endsWith(String text, String words) {
    final t = text.toLowerCase(), w = words.toLowerCase();
    return t == w || t.endsWith(' $w');
  }
}
