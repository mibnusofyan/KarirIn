import 'package:flutter_test/flutter_test.dart';
import 'package:karirin/logic/voice_transcript.dart';

void main() {
  test('partials replace each other until the result is final', () {
    final t = VoiceTranscript()
      ..add('Saya', finished: false)
      ..add('Saya memimpin', finished: false)
      ..add('Saya memimpin tim', finished: false);
    expect(t.text, 'Saya memimpin tim');

    t.add('Saya memimpin tim lima orang', finished: true);
    expect(t.text, 'Saya memimpin tim lima orang');
  });

  test('segments after a pause are appended, not overwritten', () {
    final t = VoiceTranscript()
      ..add('Saya memimpin tim', finished: false)
      ..add('Saya memimpin tim lima orang', finished: true)
      ..add('Kami', finished: false);
    expect(t.text, 'Saya memimpin tim lima orang Kami');

    t
      ..add('Kami berhasil', finished: false)
      ..add('Kami berhasil menaikkan penjualan', finished: true)
      ..add('Hasilnya naik 20 persen', finished: true);
    expect(t.text, 'Saya memimpin tim lima orang Kami berhasil menaikkan penjualan Hasilnya naik 20 persen');
  });

  test('an empty final result keeps the transcript', () {
    final t = VoiceTranscript()
      ..add('Saya memimpin tim lima orang', finished: true)
      ..add('Kami berhasil', finished: false)
      ..add('', finished: true);
    expect(t.text, 'Saya memimpin tim lima orang Kami berhasil');

    t.add('  ', finished: true);
    expect(t.text, 'Saya memimpin tim lima orang Kami berhasil');
  });

  test('a final result that repeats the segment just kept is not added twice', () {
    final t = VoiceTranscript()
      ..add('Saya memimpin tim', finished: false)
      ..add('Saya memimpin tim', finished: true)
      ..add('Saya memimpin tim', finished: true);
    expect(t.text, 'Saya memimpin tim');
  });

  test('endSegment keeps the live text when a listen ends without a final result', () {
    final t = VoiceTranscript()
      ..add('Saya memimpin tim', finished: false)
      ..endSegment()
      ..add('Kami berhasil', finished: false);
    expect(t.text, 'Saya memimpin tim Kami berhasil');

    t.endSegment();
    t.endSegment();
    expect(t.text, 'Saya memimpin tim Kami berhasil');
  });

  test('whitespace is tidied and clear starts over', () {
    final t = VoiceTranscript()..add('  Saya   memimpin\ttim ', finished: true);
    expect(t.text, 'Saya memimpin tim');

    t.clear();
    expect(t.text, '');
    t.add('Halo', finished: false);
    expect(t.text, 'Halo');
  });
}
