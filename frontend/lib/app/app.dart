import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/services/app_state.dart';
import '../l10n/app_localizations.dart';
import '../l10n/locale_controller.dart';
import '../features/auth/role_selection_screen.dart';
import '../features/caregiver/caregiver_shell.dart';
import '../features/doctor/doctor_shell.dart';
import '../features/patient/patient_shell.dart';
import 'theme/app_theme.dart';

class MemoryMitraApp extends StatefulWidget {
  const MemoryMitraApp({super.key, this.state});

  /// A pre-built, already-hydrated state. `main` passes the persistent one;
  /// tests and `const MemoryMitraApp()` fall back to an in-memory session.
  final AppState? state;

  @override
  State<MemoryMitraApp> createState() => _MemoryMitraAppState();
}

class _MemoryMitraAppState extends State<MemoryMitraApp> {
  late final AppState _state = widget.state ?? AppState();

  /// Only a state this widget created is ours to dispose.
  late final bool _ownsState = widget.state == null;

  /// Starts in English; the language is chosen in Settings.
  ///
  /// Seeding this from the profile's language would be better once the Hindi
  /// and Assamese strings have been reviewed by a native speaker — see
  /// `lib/l10n/README.md`. Until then, opening straight into an unreviewed
  /// translation is the riskier default, so the choice stays explicit.
  /// `LocaleController.fromPatientLanguage` is ready for that switch.
  late final LocaleController _locale = LocaleController();

  /// Lets a demo boot straight into one role, skipping the role picker:
  ///
  ///     flutter run --dart-define=MM_START=patient
  ///
  /// Accepts `patient`, `caregiver` or `doctor`; anything else starts normally.
  static const String _startRole = String.fromEnvironment('MM_START');

  @override
  void initState() {
    super.initState();
    switch (_startRole) {
      case 'patient':
        _state.setRole(AppRole.patient);
      case 'caregiver':
        _state.setRole(AppRole.caregiver);
      case 'doctor':
        _state.setRole(AppRole.doctor);
    }
  }

  Widget get _home => switch (_startRole) {
    'patient' => const PatientShell(),
    'caregiver' => const CaregiverShell(),
    'doctor' => const DoctorShell(),
    _ => const RoleSelectionScreen(),
  };

  @override
  void dispose() {
    _locale.dispose();
    if (_ownsState) _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: LocaleScope(
        controller: _locale,
        child: AnimatedBuilder(
          // Listens to both, so a language change and a settings change each
          // rebuild the app in place — no restart for either.
          animation: Listenable.merge(<Listenable>[_state, _locale]),
          builder: (BuildContext context, _) {
            return MaterialApp(
              title: 'MemoryMitra',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.warm(highContrast: _state.highContrast),
              scrollBehavior: const _AppScrollBehavior(),
              locale: _locale.locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: _home,
              builder: (BuildContext context, Widget? child) {
                // Patient-facing text scaling is a product setting, not an OS one,
                // so the caregiver can enlarge type on the patient's behalf.
                final double scale = _state.role == AppRole.patient ? _state.textSize.scale : 1.0;
                final MediaQueryData mq = MediaQuery.of(context);
                return MediaQuery(
                  data: mq.copyWith(
                    textScaler: TextScaler.linear(scale * mq.textScaler.scale(1).clamp(0.9, 1.2)),
                  ),
                  child: child ?? const SizedBox.shrink(),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// On the web and desktop Flutter only scrolls to touch and trackpad input, so
/// a mouse drag does nothing — including on the onboarding `PageView`. Elderly
/// users and caregivers on a desktop browser reach for a drag first, so we let
/// the mouse drive scrollables the same way a finger does.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
