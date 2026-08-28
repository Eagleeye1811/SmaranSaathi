import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../services/auth_service.dart';
import 'ui_kit.dart';

/// "Signed in as…" + log out, shown on the caregiver/doctor profile screens.
///
/// Renders nothing when there's no `AuthGate` above it in the tree
/// (`AuthScope.maybeOf` returns `null`) — which is the case for every
/// existing test and for any build without Firebase configured, so this is
/// invisible everywhere it isn't relevant, not just conditionally styled.
class AccountSection extends StatefulWidget {
  const AccountSection({super.key});

  @override
  State<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<AccountSection> {
  Future<Map<String, dynamic>?>? _me;
  AuthService? _service;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AuthService? service = AuthScope.maybeOf(context);
    if (service != _service) {
      _service = service;
      // Proves the whole chain for real: a real ID token, sent to the real
      // backend, verified there, and the response's role/email displayed
      // here — not just "the client thinks it's signed in".
      _me = service?.fetchMe();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthService? service = _service;
    if (service == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(title: 'Account', icon: Icons.badge_outlined),
        MmCard(
          child: FutureBuilder<Map<String, dynamic>?>(
            future: _me,
            builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>?> snapshot) {
              final Map<String, dynamic>? me = snapshot.data;
              final String email = (me?['email'] as String?) ?? service.currentUser?.email ?? '—';
              final String? role = me?['role'] as String?;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const SoftIcon(icon: Icons.person_outline_rounded, color: AppColors.primary, size: 46),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Signed in as', style: AppText.caption),
                            Text(email, style: AppText.body.wght(700)),
                            if (role != null)
                              Text('Role: $role', style: AppText.bodySmall.tint(AppColors.inkMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  SoftButton(
                    label: 'Log out',
                    icon: Icons.logout_rounded,
                    color: AppColors.danger,
                    onPressed: () => service.signOut(),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: Insets.lg),
      ],
    );
  }
}
