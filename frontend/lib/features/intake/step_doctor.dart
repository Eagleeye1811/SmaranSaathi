import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/models/assessment.dart';
import '../../core/models/doctor.dart';
import '../../core/services/app_state.dart';
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
class DoctorConnectStep extends StatefulWidget {
  const DoctorConnectStep({super.key, required this.onDone, this.onBack});

  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  State<DoctorConnectStep> createState() => _DoctorConnectStepState();
}

class _DoctorConnectStepState extends State<DoctorConnectStep> {
  bool _addingOwn = false;

  final TextEditingController _name = TextEditingController();
  final TextEditingController _spec = TextEditingController();
  final TextEditingController _clinic = TextEditingController();
  final TextEditingController _email = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _spec.dispose();
    _clinic.dispose();
    _email.dispose();
    super.dispose();
  }

  void _addOwnDoctor(AppState state) {
    final String name = _name.text.trim();
    if (name.isEmpty) return;
    final String id = 'doc_${DateTime.now().millisecondsSinceEpoch}';
    state.addDoctor(DoctorProfile(
      id: id,
      name: name,
      specialization: _spec.text.trim(),
      hospital: _clinic.text.trim(),
      email: _email.text.trim(),
      avatarInitials: name[0].toUpperCase(),
      status: InvitationStatus.notSent,
    ));
    state.inviteDoctor(id);
    setState(() => _addingOwn = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invitation sent to Dr. $name')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppState state = AppScope.of(context);
    const IntakeStep here = IntakeStep.doctor;

    final List<DoctorProfile> invited = state.doctorDirectory
        .where((DoctorProfile d) => d.status.isWaiting)
        .toList(growable: false);
    final DoctorProfile? connected = state.connectedDoctor;

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

        // ── Their own doctor ─────────────────────────────────────────
        if (_addingOwn) ...<Widget>[
          QuestionLabel('Your doctor', hint: 'We will send them an invitation'),
          IntakeField(label: 'Name', controller: _name, onChanged: () => setState(() {})),
          IntakeField(
              label: 'Specialisation',
              hint: 'Neurologist, physician…',
              controller: _spec,
              onChanged: () {}),
          IntakeField(
              label: 'Clinic or hospital', controller: _clinic, onChanged: () {}),
          IntakeField(
              label: 'Their email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              onChanged: () {}),
          const SizedBox(height: Insets.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: SoftButton(
                  label: l.actionCancel,
                  color: AppColors.inkSoft,
                  onPressed: () => setState(() => _addingOwn = false),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                flex: 2,
                child: SoftButton(
                  label: 'Send Invitation',
                  icon: Icons.send_rounded,
                  color: AppColors.primary,
                  filled: true,
                  onPressed:
                      _name.text.trim().isEmpty ? null : () => _addOwnDoctor(state),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
        ] else ...<Widget>[
          SoftButton(
            label: 'I already have a doctor',
            icon: Icons.person_add_alt_rounded,
            onPressed: () => setState(() => _addingOwn = true),
          ),
          const SizedBox(height: Insets.lg),
        ],

        // ── Or one from the directory ────────────────────────────────
        Text('Or choose a memory clinic near you', style: AppText.overline),
        const SizedBox(height: Insets.sm),
        for (final DoctorProfile d in state.doctorDirectory)
          if (d.status == InvitationStatus.notSent)
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
                      onPressed: () {
                        state.inviteDoctor(d.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Invitation sent to ${d.displayName}')),
                        );
                      },
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
