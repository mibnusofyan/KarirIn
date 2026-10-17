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

  test('an empty partial in the middle of speech does not wipe the live text', () {
    // Seen on a Xiaomi 2406APNFAG: "Saya bekerja", then "", then the listen ended without a final result.
    final t = VoiceTranscript()
      ..add('Saya', finished: false)
      ..add('Saya bekerja', finished: false)
      ..add('', finished: false);
    expect(t.text, 'Saya bekerja');

    t.newListen();
    expect(t.text, 'Saya bekerja');
  });

  test('after an empty partial, new words start a segment and continued words do not', () {
    final t = VoiceTranscript()
      ..add('Saya bekerja', finished: false)
      ..add('', finished: false)
      ..add('di toko roti', finished: false);
    expect(t.text, 'Saya bekerja di toko roti');

    t
      ..add('di toko roti selama dua tahun', finished: true)
      ..add('Saya', finished: false)
      ..add('', finished: false)
      ..add('saya membuat jadwal', finished: false);
    expect(t.text, 'Saya bekerja di toko roti selama dua tahun saya membuat jadwal');
  });

  test('a settled segment that drops the first words of its partial keeps the partial', () {
    // Seen on a Xiaomi 2406APNFAG: partial "are sales went up by 20%", then intermediate "20%".
    final t = VoiceTranscript()
      ..add('I made a new schedule for the whole team', finished: true)
      ..add('are sales went up by', finished: false)
      ..add('are sales went up by 20%', finished: false)
      ..add('20%', finished: true)
      ..add('20%', finished: true);
    expect(t.text, 'I made a new schedule for the whole team are sales went up by 20%');

    // A settled revision of the partial still replaces it.
    t
      ..add('I made a new skedule', finished: false)
      ..add('I made a new schedule', finished: true);
    expect(t.text, 'I made a new schedule for the whole team are sales went up by 20% I made a new schedule');
  });

  test('a settled result that overlaps the end of its partial keeps the words before the overlap', () {
    expect(
      (VoiceTranscript()
            ..add('are sales went up', finished: false)
            ..add('went up by 20 percent', finished: true))
          .text,
      'are sales went up by 20 percent',
    );
    expect(
      (VoiceTranscript()
            ..add('saya bekerja di toko saya membuat', finished: false)
            ..add('saya membuat jadwal', finished: true))
          .text,
      'saya bekerja di toko saya membuat jadwal',
    );
    // A revision that only shares its first word with the partial's last word is not joined.
    expect(
      (VoiceTranscript()
            ..add('saya bekerja di toko saya', finished: false)
            ..add('saya bekerja di toko roti', finished: true))
          .text,
      'saya bekerja di toko roti',
    );
  });

  test('after an empty partial, words that overlap the cleared text continue it', () {
    final t = VoiceTranscript()
      ..add('saya bekerja di toko', finished: false)
      ..add('', finished: false)
      ..add('di toko roti', finished: false);
    expect(t.text, 'saya bekerja di toko roti');

    // A new sentence that starts like the cleared one does not replace it.
    final u = VoiceTranscript()
      ..add('saya menyusun prioritas', finished: false)
      ..add('', finished: false)
      ..add('saya membuat jadwal', finished: false);
    expect(u.text, 'saya menyusun prioritas saya membuat jadwal');
  });

  test('a final result that repeats the segment just kept is not added twice', () {
    final t = VoiceTranscript()
      ..add('Saya memimpin tim', finished: false)
      ..add('Saya memimpin tim', finished: true)
      ..add('Saya memimpin tim', finished: true);
    expect(t.text, 'Saya memimpin tim');
  });

  test('a repeat is only ignored within the listen that settled it', () {
    final t = VoiceTranscript()
      ..add('iya', finished: false)
      ..add('iya', finished: true)
      ..add('iya', finished: true);
    expect(t.text, 'iya');

    // The next listen can settle the same short answer without showing a partial first.
    t
      ..newListen()
      ..add('', finished: false)
      ..add('iya', finished: true);
    expect(t.text, 'iya iya');
  });

  test('newListen keeps the live text when a listen ends without a final result', () {
    final t = VoiceTranscript()
      ..add('Saya memimpin tim', finished: false)
      ..newListen()
      ..add('Kami berhasil', finished: false);
    expect(t.text, 'Saya memimpin tim Kami berhasil');

    t.newListen();
    t.newListen();
    expect(t.text, 'Saya memimpin tim Kami berhasil');
  });

  test('the three-part answer recorded on the phone comes out whole', () {
    // Abbreviated id_ID results from the Xiaomi 2406APNFAG: a 3 s pause after the first part and an 8 s pause after the
    // second, which ended the listen, so the screen listened again.
    const situation = 'saat magang di bagian Keuangan saya harus menyelesaikan rekap kas dan rekonsiliasi bank di minggu yang sama';
    const action = 'jadi saya menyusun prioritas berdasarkan tenggat dan mengerjakan rekonsiliasi lebih dulu';
    const result = 'hasilnya kedua Laporan selesai sehari lebih cepat tanpa revisi dari atasan';
    final t = VoiceTranscript()
      ..add('saat magang di bagian keuangan', finished: false)
      ..add(situation, finished: true)
      ..add('', finished: false)
      ..add(' jadi saya', finished: false)
      ..add(' $action', finished: true)
      ..newListen()
      ..add('hasilnya kedua Laporan', finished: false)
      ..add(result, finished: true)
      ..add(result, finished: true);
    expect(t.text, '$situation $action $result');
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
