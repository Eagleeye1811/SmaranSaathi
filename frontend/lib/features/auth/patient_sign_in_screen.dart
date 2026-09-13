import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/services/app_state.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/pairing_service.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/companion.dart';
import '../../core/widgets/motifs.dart';
import '../../core/widgets/ui_kit.dart';
import '../../l10n/app_localizations.dart';
import '../intake/intake_kit.dart';
import '../patient/patient_shell.dart';

/// How a patient signs in on their own phone.
///
/// They type the short name their caregiver chose for them and press one
/// button. No password, because a password is the one thing a person with
/// memory loss cannot be asked to hold — and no email, because the account
/// was never theirs to create. Their caregiver approves the device instead,
/// which is both the security boundary and the moment a family member
/// actually wants to be involved in.
class PatientSignInScreen extends StatefulWidget {
  const PatientSignInScreen({super.key});

  @override
  State<PatientSignInScreen> createState() => _PatientSignInScreenState();
}

class _PatientSignInScreenState extends State<PatientSignInScreen> {
  final TextEditingController _username = TextEditingController();

  late final AppState _state = AppScope.read(context);

  Timer? _poll;
  PairingRequest? _request;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _poll?.cancel();
    _username.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final PairingService? pairing = _state.pairing;
    final AppLocalizations l = AppLocalizations.of(context);
    if (pairing == null) {
      setState(() => _error = l.pairOffline);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final PairingRequest request = await pairing.requestAccess(
        username: _username.text.trim(),
        deviceId: _state.patient.id,
        deviceLabel: _username.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _request = request;
        _busy = false;
      });
      _startPolling(pairing, request.requestId);
    } on UnknownUsernameException {
      if (mounted) {
        setState(() {
          _error = l.pairUnknown;
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

  /// Polling rather than a socket: the backend is a plain REST service, the
  /// wait is measured in seconds, and a caregiver standing next to the person
  /// is going to tap approve almost immediately.
  void _startPolling(PairingService pairing, String requestId) {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (Timer t) async {
      final PairingRequest? latest = await pairing.statusOf(requestId);
      if (!mounted || latest == null) return;
      if (latest.status == PairingStatus.pending) return;

      t.cancel();
      setState(() => _request = latest);

      if (latest.status == PairingStatus.approved) {
        // The account this device now belongs to. Everything the app writes
        // from here is filed under it, on this phone and on the server.
        await _state.signInAccount(latest.patientId);
        // And everything the caregiver already entered comes down: without
        // this the patient's phone opens on a correctly-named but empty
        // profile, which to the person holding it is indistinguishable from
        // having lost their record.
        await _state.restoreFromServer(patientId: latest.patientId);
        if (!mounted) return;
        _state.setRole(AppRole.patient);
        AuthScope.maybeOf(context)?.declareRole(AppRole.patient.name);
        Nav.rootTo(context, const PatientShell());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final PairingRequest? request = _request;
    final bool waiting = request?.status == PairingStatus.pending;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: MotifBackground(
        opacity: 0.055,
        washColors: <Color>[
          AppColors.terracottaTint.withValues(alpha: 0.9),
          AppColors.background.withValues(alpha: 0),
        ],
        child: SafeArea(
          child: Column(
            children: <Widget>[
              // The brand mark lives in this fixed header now, not as the
              // first item of the scrolling list below — it used to sit at
              // the top of the ListView, left-aligned, on its own row below
              // the back arrow instead of sharing it. Besides the
              // inconsistent look, Android's Material 3 stretch-overscroll
              // effect visibly distorted that top item during a drag, which
              // read as the logo "going behind" the header. Moving it here,
              // outside anything scrollable, fixes both at once.
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.sm, 6, Insets.gutter, 8),
                child: Row(
                  children: <Widget>[
                    RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Expanded(
                      child: Center(
                        child: BrandLockup(size: 38, center: true),
                      ),
                    ),
                    // Balances the leading button's width so the brand mark
                    // above is centred on the row, not just centred in the
                    // space left over after the button.
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.xl),
                  children: <Widget>[
                    FadeInUp(
                      child: Center(
                        child: Companion(
                          state: waiting ? CompanionState.thinking : CompanionState.happy,
                          size: 120,
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),

                    if (!waiting) ...<Widget>[
                      FadeInUp(
                        delayMs: 100,
                        child: Column(
                          children: <Widget>[
                            Text(l.authPatientEntry,
                                textAlign: TextAlign.center, style: AppText.h1.sized(26)),
                            const SizedBox(height: Insets.sm),
                            Text(
                              l.authPatientEntryBody,
                              textAlign: TextAlign.center,
                              style: AppText.body.copyWith(color: AppColors.inkSoft),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Insets.lg),
                      FadeInUp(
                        delayMs: 140,
                        child: IntakeField(
                          label: l.pairUsernameLabel,
                          controller: _username,
                          autofocus: true,
                          onChanged: () => setState(() => _error = null),
                        ),
                      ),
                      if (_error != null) ...<Widget>[
                        Text(_error!, style: AppText.bodySmall.copyWith(color: AppColors.danger)),
                        const SizedBox(height: Insets.sm),
                      ],
                      FadeInUp(
                        delayMs: 180,
                        // Reaching the backend can now take a real few
                        // seconds if it's asleep (see PairingService's
                        // longer timeout) — the button says so instead of
                        // just going quiet and looking stuck, the same
                        // "Signing you in…" pattern the role picker already
                        // uses for its own network wait.
                        child: BigButton(
                          label: _busy ? l.authSigningIn : l.pairAskAction,
                          icon: _busy ? null : Icons.waving_hand_rounded,
                          onPressed: _busy || _username.text.trim().isEmpty ? null : _ask,
                        ),
                      ),
                    ] else ...<Widget>[
                      FadeInUp(
                        child: Text(l.pairWaitingTitle,
                            textAlign: TextAlign.center, style: AppText.h1.sized(26)),
                      ),
                      const SizedBox(height: Insets.sm),
                      FadeInUp(
                        delayMs: 40,
                        child: Text(
                          l.pairWaitingBody,
                          textAlign: TextAlign.center,
                          style: AppText.body.copyWith(color: AppColors.inkSoft),
                        ),
                      ),
                      const SizedBox(height: Insets.lg),
                      // A soft tinted backdrop behind the spinner, the same
                      // circle-behind-glyph language `SoftIcon` uses
                      // everywhere else — a bare Material spinner floating in
                      // open space was the one place this screen still
                      // looked like a generic Flutter default rather than
                      // SmaranSaathi's own.
                      FadeInUp(
                        delayMs: 80,
                        child: Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryTint,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (request?.status == PairingStatus.declined) ...<Widget>[
                      const SizedBox(height: Insets.md),
                      Text(l.pairDeclined,
                          textAlign: TextAlign.center,
                          style: AppText.body.copyWith(color: AppColors.danger)),
                    ],
                    if (request?.status == PairingStatus.expired) ...<Widget>[
                      const SizedBox(height: Insets.md),
                      Text(l.pairExpired, textAlign: TextAlign.center, style: AppText.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
