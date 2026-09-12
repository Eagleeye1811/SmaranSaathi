import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/services/app_state.dart';
import '../../l10n/app_localizations.dart';
import '../patient/patient_shell.dart';

/// The patient's own app, opened from the caregiver's dashboard.
///
/// Not a summary and not a read-only copy: it is [PatientShell] itself, so
/// what the caregiver sees is exactly what the person in their care sees —
/// the same day, the same activities, the same companion. A caregiver setting
/// something up on someone's behalf needs the real thing, not a rendering of
/// it.
///
/// Two details make it safe to hand over:
///
///  - **The role is switched for the duration.** Patient-facing text scaling
///    is keyed off [AppState.role], so without this the screen would render
///    at caregiver sizes and misrepresent what the patient actually sees. It
///    is restored on the way out.
///  - **There is always a way back**, stated in words rather than left to a
///    system gesture, because the bar at the top is the only thing telling a
///    caregiver they are no longer in their own app.
class PatientViewScreen extends StatefulWidget {
  const PatientViewScreen({super.key});

  @override
  State<PatientViewScreen> createState() => _PatientViewScreenState();
}

class _PatientViewScreenState extends State<PatientViewScreen> {
  late final AppState _state = AppScope.read(context);

  @override
  void initState() {
    super.initState();
    // After the first frame: this notifies listeners, and notifying during a
    // build is what throws "setState() called during build".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _state.beginPatientPreview();
    });
  }

  @override
  void dispose() {
    // Straight onto the state, not through setState — this widget is going
    // away and only the caregiver's app is left to rebuild. Ending the
    // preview restores the role the caregiver arrived with, so backing out
    // of here can never leave them in their own app as the patient.
    _state.endPatientPreview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return PopScope(
      // The hardware back button leaves the preview the same way the bar at
      // the top does. Without this, a gesture could pop past this screen and
      // unwind into whatever the caregiver's stack had underneath, with the
      // preview never formally ended.
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) _state.endPatientPreview();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: <Widget>[
          Material(
            color: AppColors.terracottaTint,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Insets.sm, 6, Insets.md, 6),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.terracotta,
                      tooltip: l.caregiverBackToCaregiver,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            l.caregiverViewingAsPatient,
                            style: AppText.caption.copyWith(
                              color: AppColors.terracotta,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            l.caregiverBackToCaregiver,
                            style: AppText.caption.copyWith(color: AppColors.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Expanded(child: PatientShell()),
        ],
      ),
    ),
    );
  }
}
