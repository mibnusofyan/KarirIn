/// Which data source the app runs on, chosen at build time:
/// `--dart-define=BACKEND=firebase` or `--dart-define=BACKEND=mock` (default).
///
/// Mock keeps the offline prototype data, so tests, the web preview and a backup demo APK work without Firebase.
library;

enum Backend { mock, firebase }

const backend = String.fromEnvironment('BACKEND') == 'firebase' ? Backend.firebase : Backend.mock;
