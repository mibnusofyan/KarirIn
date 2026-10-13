import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// The app's identity towards YouTube. Embedded players must name their client in the HTTP Referer, and for apps
/// that is the app id as an https origin; without it YouTube refuses to play (error 152/153). The player page is
/// loaded with this base URL, so the WebView sends it as the Referer of the embed request.
const youtubeEmbedOrigin = 'https://id.karirin.karirin';

/// A YouTube video played inside the app through the official IFrame Player API in a WebView.
/// Links out of the player (YouTube logo, "Tonton di YouTube") are blocked, so the learner stays in KarirIn.
class YoutubeEmbed extends StatefulWidget {
  const YoutubeEmbed({super.key, required this.videoId, required this.onError});
  final String videoId;

  /// The IFrame API error code (2, 5, 100, 101, 150, …), or -1 when the player script could not load.
  final ValueChanged<int> onError;

  @override
  State<YoutubeEmbed> createState() => YoutubeEmbedState();
}

class YoutubeEmbedState extends State<YoutubeEmbed> {
  late final WebViewController _web = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.black)
    ..addJavaScriptChannel('KarirIn', onMessageReceived: (m) => widget.onError(int.tryParse(m.message) ?? -1))
    ..setNavigationDelegate(
      NavigationDelegate(
        // The embed itself loads in a sub-frame; a top-level navigation can only be a link out to YouTube.
        onNavigationRequest: (r) =>
            r.isMainFrame && !r.url.startsWith(youtubeEmbedOrigin) ? NavigationDecision.prevent : NavigationDecision.navigate,
      ),
    );

  @override
  void initState() {
    super.initState();
    if (_web.platform case final AndroidWebViewController android) android.setMediaPlaybackRequiresUserGesture(false);
    reload();
  }

  /// Loads (or reloads after an error) the player page.
  void reload() => _web.loadHtmlString(_playerHtml(widget.videoId), baseUrl: '$youtubeEmbedOrigin/');

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _web);
}

String _playerHtml(String videoId) =>
    '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>html,body{margin:0;width:100%;height:100%;background:#000;overflow:hidden}#player{position:absolute;top:0;left:0;width:100%;height:100%}</style>
</head>
<body>
<div id="player"></div>
<script>
function onYouTubeIframeAPIReady() {
  new YT.Player('player', {
    width: '100%',
    height: '100%',
    videoId: '$videoId',
    playerVars: {playsinline: 1, rel: 0, fs: 0, autoplay: 1, hl: 'id', cc_lang_pref: 'id', origin: '$youtubeEmbedOrigin', widget_referrer: '$youtubeEmbedOrigin'},
    events: {
      onReady: function (e) { e.target.playVideo(); },
      onError: function (e) { KarirIn.postMessage(String(e.data)); }
    }
  });
}
</script>
<script src="https://www.youtube.com/iframe_api" onerror="KarirIn.postMessage('-1')"></script>
</body>
</html>
''';
