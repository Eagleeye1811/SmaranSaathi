import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/services/app_state.dart';
import '../../core/services/pairing_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../l10n/app_localizations.dart';
import '../intake/intake_kit.dart';

/// Claiming the short name the patient will sign in with.
///
/// Asked once, the first time the caregiver opens the patient's side of the
/// app, because that is the moment the patient's account becomes a thing that
/// exists rather than a row in the caregiver's record.
///
/// Returns the claimed username, or null if the caregiver backed out.
Future<String?> claimPatientUsername(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ClaimSheet(),
  );
}

class _ClaimSheet extends StatefulWidget {
  const _ClaimSheet();

  @override
  State<_ClaimSheet> createState() => _ClaimSheetState();
}

class _ClaimSheetState extends State<_ClaimSheet> {
  final TextEditingController _username = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    final AppState state = AppScope.read(context);
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
        // With no signed-in account the patient id stands in, so a local-only
        // install still pairs correctly on the same backend.
        caregiverUid: state.accountId ?? 'local-${state.patient.id}',
        patientName: state.patient.name,
      );
      if (!mounted) return;
      Navigator.of(context).pop(claim.username);
    } on UsernameTakenException {
      if (mounted) {
        setState(() {
          _error = l.pairTaken;
          _busy = false;
        });
      }
    } on PairingUnsupportedException {
      // Reached a server, just not one that can do this. Saying "check your
      // connection" would send them looking in entirely the wrong place.
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Corners.lg)),
        ),
        padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.md, Insets.gutter, Insets.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(l.pairChooseTitle, style: AppText.h3),
              const SizedBox(height: Insets.xs),
              Text(l.pairChooseBody, style: AppText.bodySmall.copyWith(height: 1.5)),
              const SizedBox(height: Insets.md),
              IntakeField(
                label: l.pairUsernameLabel,
                controller: _username,
                onChanged: () => setState(() => _error = null),
              ),
              if (_error != null) ...<Widget>[
                Text(_error!, style: AppText.bodySmall.copyWith(color: AppColors.danger)),
                const SizedBox(height: Insets.sm),
              ],
              BigButton(
                label: l.pairChooseAction,
                icon: Icons.check_rounded,
                onPressed: _busy || _username.text.trim().isEmpty ? null : _claim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The caregiver's side of the handshake: a device somewhere is asking to sign
/// in as their patient, and only this screen can say yes.
///
/// Polls rather than listens, for the same reason the patient's side does —
/// a plain REST backend, and a wait measured in seconds. It only runs while
/// the dashboard is on screen, so it costs nothing when the app is closed.
class PairingRequestBanner extends StatefulWidget {
  const PairingRequestBanner({super.key});

  @override
  State<PairingRequestBanner> createState() => _PairingRequestBannerState();
}

class _PairingRequestBannerState extends State<PairingRequestBanner> {
  late final AppState _state = AppScope.read(context);
  Timer? _poll;
  List<PairingRequest> _pending = const <PairingRequest>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  String get _uid => _state.accountId ?? 'local-${_state.patient.id}';

  Future<void> _refresh() async {
    final PairingService? pairing = _state.pairing;
    if (pairing == null || !_state.hasPatientUsername) return;
    final List<PairingRequest> next = await pairing.pendingFor(_uid);
    if (mounted) setState(() => _pending = next);
  }

  Future<void> _respond(PairingRequest request, bool approve) async {
    final PairingService? pairing = _state.pairing;
    if (pairing == null) return;
    setState(() => _busy = true);
    await pairing.respond(
      requestId: request.requestId,
      caregiverUid: _uid,
      approve: approve,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pending = <PairingRequest>[
        for (final PairingRequest r in _pending)
          if (r.requestId != request.requestId) r,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_pending.isEmpty) return const SizedBox.shrink();
    final AppLocalizations l = AppLocalizations.of(context);
    final String name = _state.patient.shortName;

    return Column(
      children: <Widget>[
        for (final PairingRequest r in _pending)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.md),
            child: MmCard(
              color: AppColors.accentTint,
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const SoftIcon(
                        icon: Icons.phonelink_ring_rounded,
                        size: 42,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: Insets.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              l.pairIncomingTitle(
                                r.deviceLabel.isEmpty ? r.deviceId : r.deviceLabel,
                                name,
                              ),
                              style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(l.pairIncomingBody, style: AppText.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: SoftButton(
                          label: l.pairDecline,
                          icon: Icons.close_rounded,
                          onPressed: _busy ? null : () => _respond(r, false),
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      Expanded(
                        child: BigButton(
                          label: l.pairApprove,
                          icon: Icons.check_rounded,
                          height: 52,
                          color: AppColors.accent,
                          onPressed: _busy ? null : () => _respond(r, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
