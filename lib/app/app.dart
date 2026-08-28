import 'package:flutter/material.dart';

import '../core/services/app_state.dart';
import '../features/auth/role_selection_screen.dart';
import '../features/caregiver/caregiver_shell.dart';
import '../features/doctor/doctor_shell.dart';
import '../features/patient/patient_shell.dart';
import 'theme/app_theme.dart';

class MemoryMitraApp extends StatefulWidget {
  const MemoryMitraApp({super.key});

  @override
  State<MemoryMitraApp> createState() => _MemoryMitraAppState();
}

class _MemoryMitraAppState extends State<MemoryMitraApp> {
  final AppState _state = AppState();

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
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: AnimatedBuilder(
        animation: _state,
        builder: (BuildContext context, _) {
          return MaterialApp(
            title: 'MemoryMitra',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.warm(highContrast: _state.highContrast),
            home: _home,
            builder: (BuildContext context, Widget? child) {
              // Patient-facing text scaling is a product setting, not an OS one,
              // so the caregiver can enlarge type on the patient's behalf.
              final double scale = _state.role == AppRole.patient
                  ? _state.textSize.scale
                  : 1.0;
              final MediaQueryData mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: TextScaler.linear(
                    scale * mq.textScaler.scale(1).clamp(0.9, 1.2),
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
