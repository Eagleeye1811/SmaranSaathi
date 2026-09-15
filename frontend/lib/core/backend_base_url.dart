/// The one place that decides which backend this build talks to.
///
/// There used to be two answers. `bootstrap.dart` defaulted to the deployed
/// service, while `TelehealthService`, `DoctorPatientChatService`,
/// `WeeklyReportService` and the Asha screen each defaulted to
/// `http://10.0.2.2:8000` — the host machine's localhost as seen from an
/// Android emulator. With no `--dart-define` that meant sync reached
/// production while those four quietly reached a server that, on most
/// machines, nothing was listening on. For the video call it was fatal
/// rather than degraded: the signaling socket could never open, so the
/// offer was dropped before it left the device and the call simply never
/// connected.
///
/// Override for local development exactly as before:
///
///     flutter run --dart-define=MM_SYNC_BASE_URL=http://10.0.2.2:8000
library;

const String _configured = String.fromEnvironment('MM_SYNC_BASE_URL');

/// The deployed backend (Render) — a public API endpoint, not a secret.
const String deployedBackendBaseUrl = 'https://smaransaathi-backend.onrender.com';

/// What every client in the app should use unless it was handed a URL.
String get backendBaseUrl => _configured.isNotEmpty ? _configured : deployedBackendBaseUrl;
