import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/backend.dart';
import 'firebase/bootstrap.dart';
import 'router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (backend == Backend.firebase) await initFirebase();
  runApp(const ProviderScope(child: KarirInApp()));
}

/// Light system bars for every screen; the splash overrides this with its own navy region.
const _defaultSystemUi = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: KColors.surface,
  systemNavigationBarIconBrightness: Brightness.dark,
);

class KarirInApp extends StatelessWidget {
  const KarirInApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'KarirIn',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    locale: const Locale('id'),
    supportedLocales: const [Locale('id')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: router,
    builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(value: _defaultSystemUi, child: child!),
  );
}
