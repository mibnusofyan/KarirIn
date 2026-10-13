import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/repositories/profile_repository.dart';
import '../state/app_state.dart';
import '../theme/career_theme.dart';
import 'career_widgets.dart';
import 'common.dart';

/// The user's profile photo, or their initials on the brand yellow while there is none.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.initials, this.photo, this.radius = 30});
  final String initials;
  final Uint8List? photo;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: CareerColors.yellow,
    foregroundImage: photo == null ? null : MemoryImage(photo!),
    child: Text(
      initials,
      textScaler: TextScaler.noScaling,
      style: CareerText.title.copyWith(fontSize: radius * .67, color: CareerColors.navy),
    ),
  );
}

/// The avatar with a camera badge; tapping it takes a new photo, picks one from the gallery, or removes it.
class ProfilePhotoButton extends ConsumerWidget {
  const ProfilePhotoButton({super.key, this.radius = 30});
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(appProvider);
    final hasPhoto = st.photo != null;
    // Its own node, so screen readers announce a button instead of folding it into the profile card's text.
    return Semantics(
      container: true,
      button: true,
      label: hasPhoto ? 'Ubah foto profil' : 'Tambah foto profil',
      child: InkResponse(
        onTap: () => _showOptions(context, ref, hasPhoto: hasPhoto),
        radius: radius + 6,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ExcludeSemantics(
              child: ProfileAvatar(initials: st.profile.initials, photo: st.photo, radius: radius),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: radius * .8,
                height: radius * .8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: CareerColors.navy, width: 2),
                ),
                child: Icon(Icons.photo_camera_outlined, size: radius * .45, color: CareerColors.navy),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showOptions(BuildContext context, WidgetRef ref, {required bool hasPhoto}) async {
    final choice = await showCareerSheet<String>(
      context,
      (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CareerSheetHeader('Foto profil'),
          const Text('Pakai foto wajah yang jelas dan sopan, seperti untuk lamaran kerja.', style: CareerText.muted),
          const SizedBox(height: 12),
          _Option(icon: Icons.photo_camera_outlined, label: 'Ambil foto dengan kamera', onTap: () => Navigator.pop(ctx, 'camera')),
          _Option(icon: Icons.photo_library_outlined, label: 'Pilih dari galeri', onTap: () => Navigator.pop(ctx, 'gallery')),
          if (hasPhoto)
            _Option(
              icon: Icons.delete_outline_rounded,
              label: 'Hapus foto',
              color: CareerColors.error,
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    final notifier = ref.read(appProvider.notifier);
    if (choice == 'remove') {
      notifier.removePhoto();
      showToast(context, 'Foto profil dihapus');
      return;
    }
    final XFile? file;
    try {
      // Small enough to keep in Firestore: the avatar is never shown larger than ~120 px.
      file = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
    } on PlatformException {
      if (context.mounted) showToast(context, choice == 'camera' ? 'Kamera tidak dapat dibuka.' : 'Galeri tidak dapat dibuka.');
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    if (bytes.length > maxProfilePhotoBytes) {
      showToast(context, 'Foto terlalu besar. Pilih foto lain.');
      return;
    }
    notifier.setPhoto(bytes);
    showToast(context, 'Foto profil diperbarui');
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.icon, required this.label, required this.onTap, this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color ?? CareerColors.navy),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: CareerText.label.copyWith(color: color ?? CareerColors.ink)),
          ),
        ],
      ),
    ),
  );
}
