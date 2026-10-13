import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../theme/career_theme.dart';
import '../widgets/youtube_embed.dart';

/// Plays a skill's learning video inside KarirIn, so the learner never leaves the app for YouTube.
/// "Layar penuh" (or turning the phone sideways) shows only the video in landscape.
class VideoLessonScreen extends StatefulWidget {
  const VideoLessonScreen({super.key, required this.skill, required this.resource});
  final String skill;
  final LearningResource resource;

  /// Opens the player above the current sheet; closing it returns to the sheet with its actions.
  static Future<void> open(BuildContext context, {required String skill, required LearningResource resource}) =>
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => VideoLessonScreen(skill: skill, resource: resource),
        ),
      );

  @override
  State<VideoLessonScreen> createState() => _VideoLessonScreenState();
}

class _VideoLessonScreenState extends State<VideoLessonScreen> {
  // Keeps the same WebView (and playback) when the player moves between the portrait and fullscreen layouts.
  final _player = GlobalKey<YoutubeEmbedState>();
  bool _fullscreen = false;
  int? _error;

  Future<void> _setFullscreen(bool on) async {
    setState(() => _fullscreen = on);
    await SystemChrome.setPreferredOrientations(on ? const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight] : const []);
    await SystemChrome.setEnabledSystemUIMode(on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  void _retry() {
    setState(() => _error = null);
    _player.currentState?.reload();
  }

  @override
  void dispose() {
    if (_fullscreen) {
      SystemChrome.setPreferredOrientations(const []);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final res = widget.resource;
    final player = YoutubeEmbed(key: _player, videoId: res.youtubeId!, onError: (code) => setState(() => _error = code));
    final full = _fullscreen || MediaQuery.orientationOf(context) == Orientation.landscape;

    if (full) {
      return PopScope(
        canPop: !_fullscreen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _setFullscreen(false);
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(child: player),
              Positioned(
                top: 8,
                right: 8,
                child: SafeArea(
                  child: IconButton.filledTonal(
                    tooltip: 'Keluar layar penuh',
                    onPressed: () => _fullscreen ? _setFullscreen(false) : Navigator.of(context).pop(),
                    icon: Icon(_fullscreen ? Icons.fullscreen_exit_rounded : Icons.close_rounded),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return CareerTheme(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('Belajar ${widget.skill}'),
        ),
        body: ListView(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(color: Colors.black, child: player),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('VIDEO · ${res.duration} · GRATIS', style: CareerText.eyebrow)),
                      TextButton.icon(
                        onPressed: () => _setFullscreen(true),
                        icon: const Icon(Icons.fullscreen_rounded, size: 20),
                        label: const Text('Layar penuh'),
                      ),
                    ],
                  ),
                  Text(res.title, style: CareerText.title),
                  if (res.provider != null) ...[const SizedBox(height: 4), Text('Oleh ${res.provider} · YouTube', style: CareerText.small)],
                  if (_error != null) ...[const SizedBox(height: 16), _ErrorBox(code: _error!, onRetry: _retry)],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: CareerColors.mint, borderRadius: BorderRadius.circular(14)),
                    child: Text(
                      'Selesai menonton? Kembali, lalu tekan "Tandai dikuasai" atau unggah bukti belajarmu agar Match Score diperbarui.',
                      style: CareerText.body.copyWith(color: CareerColors.teal),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.code, required this.onRetry});
  final int code;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: CareerColors.amberLight, borderRadius: BorderRadius.circular(14)),
    child: Row(
      children: [
        Expanded(
          child: Text(
            code == -1
                ? 'Pemutar video tidak dapat dimuat. Periksa koneksi internet lalu coba lagi.'
                : 'Video ini sedang tidak dapat diputar (kode $code). Coba lagi beberapa saat lagi.',
            style: CareerText.body.copyWith(color: CareerColors.amber),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
      ],
    ),
  );
}
