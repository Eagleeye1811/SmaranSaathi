import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/services/app_state.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/companion.dart';
import '../../core/widgets/illustration.dart';
import '../../core/widgets/motifs.dart';
import '../../core/widgets/ui_kit.dart';
import '../caregiver/caregiver_shell.dart';
import '../doctor/doctor_shell.dart';
import '../patient/patient_shell.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final Size screen = MediaQuery.sizeOf(context);
    final bool tall = screen.height > 720;

    return Scaffold(
      body: MotifBackground(
        opacity: 0.055,
        washColors: <Color>[
          AppColors.primaryTint.withValues(alpha: 0.9),
          AppColors.background.withValues(alpha: 0),
        ],
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, 12, Insets.gutter, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight - 36),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const FadeInUp(child: BrandLockup(size: 46)),
                          SizedBox(height: tall ? 24 : 14),
                          FadeInUp(
                            delayMs: 60,
                            child: Center(
                              child: Companion(
                                state: CompanionState.happy,
                                size: tall ? 172 : 132,
                              ),
                            ),
                          ),
                          SizedBox(height: tall ? 14 : 8),
                          FadeInUp(
                            delayMs: 110,
                            child: Column(
                              children: <Widget>[
                                Text(
                                  'Welcome to MemoryMitra',
                                  textAlign: TextAlign.center,
                                  style: AppText.hero.sized(tall ? 30 : 26),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'I am Mitra. I keep company with the things\nyou love to remember.',
                                  textAlign: TextAlign.center,
                                  style: AppText.body.tint(AppColors.inkSoft),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: tall ? 28 : 20),
                          FadeInUp(
                            delayMs: 150,
                            child: Row(
                              children: <Widget>[
                                const Expanded(child: Divider(color: AppColors.hairline)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Text('WHO ARE YOU?', style: AppText.overline),
                                ),
                                const Expanded(child: Divider(color: AppColors.hairline)),
                              ],
                            ),
                          ),
                          const SizedBox(height: Insets.md),
                          FadeInUp(
                            delayMs: 190,
                            child: _RoleCard(
                              sceneId: 'portrait_aama',
                              title: 'Patient',
                              name: 'Aama Devi, 72',
                              description: 'Meet your companion, play, and remember together.',
                              accent: AppColors.terracotta,
                              tint: AppColors.terracottaTint,
                              onTap: () {
                                AuthScope.maybeOf(context)?.declareRole('patient');
                                state.setRole(AppRole.patient);
                                Nav.push(context, const PatientShell());
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          FadeInUp(
                            delayMs: 230,
                            child: _RoleCard(
                              sceneId: 'portrait_priya',
                              title: 'Caregiver',
                              name: 'Priya — daughter',
                              description: 'Build her memory profile and follow her day.',
                              accent: AppColors.primary,
                              tint: AppColors.primaryTint,
                              onTap: () {
                                AuthScope.maybeOf(context)?.declareRole('caregiver');
                                state.setRole(AppRole.caregiver);
                                Nav.push(context, const CaregiverShell());
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          FadeInUp(
                            delayMs: 270,
                            child: _RoleCard(
                              icon: Icons.medical_information_rounded,
                              title: 'Doctor',
                              name: 'Dr. Neha Sharma',
                              description: 'Review cognitive performance trends across patients.',
                              accent: AppColors.secondary,
                              tint: AppColors.secondaryTint,
                              onTap: () {
                                AuthScope.maybeOf(context)?.declareRole('doctor');
                                state.setRole(AppRole.doctor);
                                Nav.push(context, const DoctorShell());
                              },
                            ),
                          ),
                          SizedBox(height: tall ? 26 : 18),
                          FadeInUp(
                            delayMs: 310,
                            child: Column(
                              children: <Widget>[
                                const WovenStrip(height: 10, opacity: 0.5),
                                const SizedBox(height: 12),
                                Text(
                                  'Prototype  ·  SIH 2026  ·  Problem Statement 26003',
                                  textAlign: TextAlign.center,
                                  style: AppText.caption.sized(11.5),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Demo data only. Not a diagnostic tool.',
                                  textAlign: TextAlign.center,
                                  style: AppText.caption.sized(11.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.name,
    required this.description,
    required this.accent,
    required this.tint,
    required this.onTap,
    this.sceneId,
    this.icon,
  });

  final String title;
  final String name;
  final String description;
  final Color accent;
  final Color tint;
  final VoidCallback onTap;
  final String? sceneId;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return MmCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      radius: Corners.lg,
      shadow: AppColors.softShadow(y: 6, blur: 18, opacity: 0.055),
      child: Row(
        children: <Widget>[
          if (sceneId != null)
            Container(
              decoration:
                  BoxDecoration(borderRadius: Corners.r(Corners.md), boxShadow: AppColors.softShadow(y: 3, blur: 8)),
              child: SceneImage(sceneId: sceneId!, size: 62, radius: Corners.md),
            )
          else
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(color: tint, borderRadius: Corners.r(Corners.md)),
              child: Icon(icon, size: 30, color: accent),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title, style: AppText.h3.wght(800)),
                const SizedBox(height: 3),
                Text(
                  name,
                  style: AppText.caption.wght(800).tint(accent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(description, style: AppText.bodySmall, maxLines: 2),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(Icons.arrow_forward_rounded, size: 19, color: accent),
          ),
        ],
      ),
    );
  }
}
