import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/assessment.dart';
import '../../core/models/doctor.dart';
import '../../core/services/app_state.dart';
import '../../core/services/doctor_connection_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../l10n/app_localizations.dart';
import 'intake_kit.dart';

/// The last thing the onboarding asks: is there a doctor in this?
///
/// Offered here because it is the moment a family has just finished
/// describing someone's difficulties, which is exactly when "who is helping
/// you with this?" is a question they have an answer to — and because a
/// caregiver who never opens the Doctors tab would otherwise never be asked.
///
/// Nothing here blocks the way forward. Sending an invitation is enough;
/// so is naming a doctor the family already has; so is saying no. A
/// questionnaire that would not end until a stranger replied would be a
/// questionnaire nobody finishes.
///
/// Every doctor named here is a real, signed-up account — there is no more
/// "add your own doctor" fabricated entry. A family whose doctor has not
/// signed up on SmaranSaathi yet has nobody to invite; the copy says so
/// plainly rather than inventing a listing that can never be answered.
class DoctorConnectStep extends StatefulWidget {
  const DoctorConnectStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<DoctorConnectStep> createState() => _DoctorConnectStepState();
}

class _DoctorConnectStepState extends State<DoctorConnectStep> {
  bool _sendingTo = false;
  String? _sendingToId;

  @override
  void initState() {
    super.initState();
    final AppState state = AppScope.read(context);
    state.loadDoctorDirectory();
    state.refreshConnectedDoctor();
  }

  Future<void> _invite(AppState state, DoctorProfile doctor) async {
    setState(() {
      _sendingTo = true;
      _sendingToId = doctor.id;
    });
    try {
      await state.inviteDoctor(doctor.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation sent to ${doctor.displayName}')),
      );
    } on DoctorAlreadyConnectedException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${doctor.displayName} is already connected to this record.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send the invitation. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingTo = false;
          _sendingToId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppState state = AppScope.of(context);
    const IntakeStep here = IntakeStep.doctor;

    final List<DoctorProfile> invited = state.doctorDirectory
        .where((DoctorProfile d) => state.statusOf(d) == InvitationStatus.sent)
        .toList(growable: false);
    final DoctorProfile? connected = state.connectedDoctor;
    final List<DoctorProfile> available = state.doctorDirectory
        .where((DoctorProfile d) => state.statusOf(d) == InvitationStatus.notSent)
        .toList(growable: false);

    return IntakeScaffold(
      stepIndex: IntakeRecord.order.indexOf(here),
      stepCount: IntakeRecord.order.length,
      partLabel: here.part.name,
      onBack: widget.onBack,
      title: 'Is a doctor involved?',
      subtitle: 'They can follow how things are going, and you can book time '
          'with them here. You can also do this later.',
      accent: AppColors.secondary,
      // Always enabled. The way forward does not depend on a stranger.
      onContinue: widget.onDone,
      continueLabel: invited.isEmpty && connected == null
          ? 'Continue without a doctor'
          : l.actionContinue,
      children: <Widget>[
        if (connected != null) ...<Widget>[
          MmCard(
            color: AppColors.successTint,
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            child: ListRow(
              padding: EdgeInsets.zero,
              leading: const SoftIcon(
                  icon: Icons.verified_rounded, color: AppColors.success),
              title: connected.displayName,
              subtitle: 'Already connected to this record',
            ),
          ),
          const SizedBox(height: Insets.lg),
        ],

        if (invited.isNotEmpty) ...<Widget>[
          for (final DoctorProfile d in invited)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MmCard(
                padding: const EdgeInsets.all(Insets.md),
                child: ListRow(
                  padding: EdgeInsets.zero,
                  leading: const SoftIcon(
                      icon: Icons.hourglass_bottom_rounded,
                      color: AppColors.accent),
                  title: d.displayName,
                  subtitle: 'Invitation sent, you can carry on while they reply',
                ),
              ),
            ),
          const SizedBox(height: Insets.lg),
        ],

        // ── Real, signed-up doctors ───────────────────────────────────
        Text('Or choose a memory clinic near you', style: AppText.overline),
        const SizedBox(height: Insets.sm),
        if (available.isEmpty)
          MmCard(
            padding: const EdgeInsets.all(Insets.md),
            child: Text(
              "Can't find your doctor? Ask them to sign up on SmaranSaathi as "
              "a doctor — they'll appear here once they do.",
              style: AppText.bodySmall,
            ),
          )
        else
          for (final DoctorProfile d in available)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MmCard(
                padding: const EdgeInsets.all(Insets.md),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(d.displayName,
                              style: AppText.body.wght(800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            d.specialization.isEmpty
                                ? d.hospital
                                : '${d.specialization} · ${d.hospital}',
                            style: AppText.caption,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    SoftButton(
                      label: 'Invite',
                      icon: Icons.send_rounded,
                      color: AppColors.primary,
                      filled: true,
                      onPressed:
                          (_sendingTo && _sendingToId == d.id) ? null : () => _invite(state, d),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: Insets.sm),
        WhyWeAsk(
          'A doctor sees the same summary you do, nothing extra, and only '
          'after they accept.',
          icon: Icons.lock_outline_rounded,
        ),
      ],
    );
  }
}
