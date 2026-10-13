import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karirin/state/app_state.dart';
import 'package:karirin/widgets/profile_photo.dart';

// A valid 1×1 PNG.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, //
  0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0, 0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  testWidgets('tanpa foto memakai inisial; dengan foto memakai gambar', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: ProfilePhotoButton())),
        ),
      ),
    );
    final initials = container.read(appProvider).profile.initials;
    expect(find.text(initials), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byType(ProfilePhotoButton)),
      containsSemantics(label: 'Tambah foto profil', isButton: true, hasTapAction: true),
    );
    semantics.dispose();
    expect(tester.widget<CircleAvatar>(find.byType(CircleAvatar)).foregroundImage, isNull);

    container.read(appProvider.notifier).setPhoto(_png);
    await tester.pump();
    expect((tester.widget<CircleAvatar>(find.byType(CircleAvatar)).foregroundImage! as MemoryImage).bytes, _png);
    expect(find.bySemanticsLabel('Ubah foto profil'), findsOneWidget);

    await tester.tap(find.byType(ProfilePhotoButton));
    await tester.pumpAndSettle();
    expect(find.text('Ambil foto dengan kamera'), findsOneWidget);
    expect(find.text('Pilih dari galeri'), findsOneWidget);
    await tester.tap(find.text('Hapus foto'));
    await tester.pumpAndSettle();
    expect(container.read(appProvider).photo, isNull);
  });
}
