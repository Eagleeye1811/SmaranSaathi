import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/assessment.dart';
import '../../core/services/app_state.dart';
import '../../core/services/pairing_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../l10n/app_localizations.dart';
import 'intake_kit.dart';

/// Sets up how the patient will sign in on their own phone, at the point
/// they actually need it: right after onboarding, not buried three taps
/// deep in the caregiver dashboard once the account already exists.
///
/// Nothing here blocks the way forward, matching [DoctorConnectStep]: a
/// username can be created now or left for later from the patient's
/// profile, so a caregiver setting this up without the patient's phone in
/// hand is never stuck.
class PatientUsernameStep extends StatefulWidget {
  const PatientUsernameStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<PatientUsernameStep> createState() => _PatientUsernameStepState();
}

class _PatientUsernameStepState extends State<PatientUsernameStep> {
  final TextEditingController _username = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _justClaimed;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _claim(AppState state) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final PairingService? pairing = state.pairing;
    if (pairing == null) {
      setState(() => _error = l.pairOffline);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final PairingClaim claim = await pairing.claim(
        username: _username.text.trim(),
        patientId: state.patient.id,
        caregiverUid: state.accountId ?? 'local-${state.patient.id}',
        patientName: state.patient.name,
      );
      state.setPatientUsername(claim.username);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _justClaimed = claim.username;
      });
    } on UsernameTakenException {
      if (mounted) {
        setState(() {
          _error = l.pairTaken;
          _busy = false;
        });
      }
    } on PairingUnsupportedException {
      if (mounted) {
        setState(() {
          _error = l.pairUnsupported;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = l.pairOffline;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppState state = AppScope.of(context);
    const IntakeStep here = IntakeStep.patientUsername;
    final bool already = _justClaimed != null || state.hasPatientUsername;
    final String username = _justClaimed ?? state.patientUsername;

    return IntakeScaffold(
      stepIndex: IntakeRecord.order.indexOf(here),
      stepCount: IntakeRecord.order.length,
      partLabel: here.part.name,
      onBack: widget.onBack,
      title: 'Give them a way to sign in',
      subtitle: 'A short username lets them sign in on their own phone, no '
          'password needed. Every new device asks you to approve it first.',
      accent: AppColors.primary,
      // Always enabled. A phone not in hand right now is not a reason to
      // stop the onboarding — this can be finished later from their profile.
      onContinue: widget.onDone,
      continueLabel: already ? l.actionContinue : 'Continue without setting this up',
      children: <Widget>[
        if (already) ...<Widget>[
          MmCard(
            color: AppColors.successTint,
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            child: ListRow(
              padding: EdgeInsets.zero,
              leading: const SoftIcon(icon: Icons.verified_rounded, color: AppColors.success),
              title: l.pairPatientUsernameIs(username),
              subtitle: 'They can sign in with this whenever they are ready',
            ),
          ),
          const SizedBox(height: Insets.lg),
        ] else ...<Widget>[
          IntakeField(
            label: l.pairUsernameLabel,
            controller: _username,
            onChanged: () => setState(() => _error = null),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: Insets.xs),
            Text(_error!, style: AppText.bodySmall.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: Insets.sm),
          SoftButton(
            label: l.pairChooseAction,
            icon: Icons.check_rounded,
            color: AppColors.primary,
            filled: true,
            onPressed: _busy || _username.text.trim().isEmpty ? null : () => _claim(state),
          ),
          const SizedBox(height: Insets.lg),
        ],
        WhyWeAsk(l.pairChooseBody, icon: Icons.lock_outline_rounded),
      ],
    );
  }
}
