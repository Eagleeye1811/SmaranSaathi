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
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.xl),
          children: <Widget>[
            const Center(child: BrandLockup(size: 42)),
            const SizedBox(height: Insets.lg),
            Center(
              child: Companion(
                state: waiting ? CompanionState.thinking : CompanionState.happy,
                size: 120,
              ),
            ),
            const SizedBox(height: Insets.lg),

            if (!waiting) ...<Widget>[
              Text(l.authPatientEntry, textAlign: TextAlign.center, style: AppText.h1.sized(26)),
              const SizedBox(height: Insets.sm),
              Text(
                l.authPatientEntryBody,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: Insets.lg),
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
                label: l.pairAskAction,
                icon: Icons.waving_hand_rounded,
                onPressed: _busy || _username.text.trim().isEmpty ? null : _ask,
              ),
            ] else ...<Widget>[
              Text(l.pairWaitingTitle, textAlign: TextAlign.center, style: AppText.h1.sized(26)),
              const SizedBox(height: Insets.sm),
              Text(
                l.pairWaitingBody,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: Insets.lg),
              const Center(child: CircularProgressIndicator()),
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
    );
  }
}
