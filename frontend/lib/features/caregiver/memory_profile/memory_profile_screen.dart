import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/patient.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/mock/mock_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/mock_translator.dart';
import '../onboarding/patient_onboarding_flow.dart';
import '../widgets/caregiver_top_bar.dart';

/// The memory profile: everything personalisation is built from, editable in
/// one place.
class MemoryProfileScreen extends StatefulWidget {
  const MemoryProfileScreen({super.key});

  @override
  State<MemoryProfileScreen> createState() => _MemoryProfileScreenState();
}

class _MemoryProfileScreenState extends State<MemoryProfileScreen> {
  int _tab = 0;

  List<String> _tabs(AppLocalizations l) => <String>[
        l.caregiverTabPeople,
        l.caregiverTabMemories,
        l.caregiverTabPhotographs,
        l.caregiverTabRoutine,
      ];

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final Patient p = state.patient;
    final List<String> tabs = _tabs(l);

    return MotifBackground(
      opacity: 0.04,
      washColors: <Color>[
        AppColors.terracottaTint.withValues(alpha: 0.7),
        AppColors.background.withValues(alpha: 0),
      ],
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            CaregiverTopBar(
                title: l.caregiverMemoryProfileTitle, subtitle: l.caregiverMemoryProfileSubtitle),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                    child: FadeInUp(child: _profileHeader(p, state, l)),
                  ),
                  const SizedBox(height: Insets.lg),
                  SizedBox(
                    height: 42,
                    child: ListView(
                      key: const Key('profile-tabs'),
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                      children: <Widget>[
                        for (int i = 0; i < tabs.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Pressable(
                              onTap: () => setState(() => _tab = i),
                              child: AnimatedContainer(
                                duration: Motion.quick,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _tab == i ? AppColors.primary : Colors.white,
                                  borderRadius: Corners.r(Corners.pill),
                                  border: Border.all(
                                    color: _tab == i ? AppColors.primary : AppColors.hairline,
                                  ),
                                ),
                                child: Text(
                                  tabs[i],
                                  style: AppText.body
                                      .wght(_tab == i ? 800 : 600)
                                      .tint(_tab == i ? Colors.white : AppColors.ink),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                    child: AnimatedSwitcher(
                      duration: Motion.normal,
                      child: KeyedSubtree(
                        key: ValueKey<int>(_tab),
                        child: switch (_tab) {
                          0 => _people(p, state, l),
                          1 => _memories(p, state, l),
                          2 => _assets(p, l),
                          _ => _routine(p, l),
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileHeader(Patient p, AppState state, AppLocalizations l) {
    return MmCard(
      shadow: AppColors.liftShadow(),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              SceneImage(
                sceneId: p.portraitScene,
                size: 76,
                circle: true,
                borderColor: Colors.white,
                borderWidth: 3,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(p.name, style: AppText.h2.sized(22)),
                    const SizedBox(height: 4),
                    Text(l.caregiverAgeLocation(p.age, p.location), style: AppText.bodySmall),
                    const SizedBox(height: 6),
                    Text(p.joinedOn, style: AppText.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              PillTag(
                  label: p.language, icon: Icons.translate_rounded, color: AppColors.secondary, dense: true),
              PillTag(
                  label: p.occupation, icon: Icons.handyman_rounded, color: AppColors.terracotta, dense: true),
              PillTag(
                  label: p.favouriteFood, icon: Icons.restaurant_rounded, color: AppColors.accent, dense: true),
              PillTag(
                  label: p.tradition, icon: Icons.celebration_rounded, color: AppColors.plum, dense: true),
            ],
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              Expanded(
                child: SoftButton(
                  label: l.caregiverRerunOnboardingButton,
                  icon: Icons.tune_rounded,
                  onPressed: () => Nav.open(context, const PatientOnboardingFlow()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── people ─────────────────────────────────────────────────────────────

  Widget _people(Patient p, AppState state, AppLocalizations l) {
    final List<FamilyMember> available = MockData.family
        .where((FamilyMember m) => !p.family.any((FamilyMember f) => f.id == m.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: l.caregiverPeopleTitle,
          subtitle: l.caregiverPeopleSubtitle,
          dense: true,
        ),
        for (final FamilyMember f in p.family)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MmCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  SceneImage(sceneId: f.sceneId, size: 58, circle: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(f.name, style: AppText.h3),
                        const SizedBox(height: 2),
                        PillTag(label: MockTranslator.translateRelation(f.relation, l), color: AppColors.terracotta, dense: true),
                        if (f.note.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(MockTranslator.translateFamilyNote(f.note, l), style: AppText.caption),
                        ],
                      ],
                    ),
                  ),
                  RoundIconButton(
                    icon: Icons.delete_outline_rounded,
                    size: 38,
                    color: AppColors.inkMuted,
                    tooltip: l.caregiverRemoveTooltip,
                    onPressed: () {
                      state.updateDraft(p);
                      final List<FamilyMember> next = List<FamilyMember>.from(p.family)
                        ..remove(f);
                      state.updateDraft(p.copyWith(family: next));
                      state.commitDraft();
                    },
                  ),
                ],
              ),
            ),
          ),
        if (available.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(l.caregiverSuggestedToAddLabel, style: AppText.overline),
          const SizedBox(height: 10),
          for (final FamilyMember f in available)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MmCard(
                padding: const EdgeInsets.all(12),
                color: AppColors.surfaceMuted,
                onTap: () {
                  final List<FamilyMember> next = List<FamilyMember>.from(p.family)..add(f);
                  state.updateDraft(p.copyWith(family: next));
                  state.commitDraft();
                },
                child: Row(
                  children: <Widget>[
                    SceneImage(sceneId: f.sceneId, size: 46, circle: true),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text('${f.name} · ${MockTranslator.translateRelation(f.relation, l)}',
                          style: AppText.body.wght(600)),
                    ),
                    const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  // ── memories ───────────────────────────────────────────────────────────

  Widget _memories(Patient p, AppState state, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: l.caregiverMemoriesTitle,
          subtitle: l.caregiverMemoriesSubtitle,
          dense: true,
        ),
        for (final LifeMemory m in p.memories)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MmCard(
              onTap: () => _editMemory(m, p, state, l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PillTag(
                              label: m.category, color: AppColors.primary, dense: true),
                        ),
                      ),
                      const Icon(Icons.edit_outlined, size: 17, color: AppColors.inkMuted),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(m.prompt, style: AppText.label),
                  const SizedBox(height: 6),
                  Text(m.answer, style: AppText.body),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _editMemory(LifeMemory m, Patient p, AppState state, AppLocalizations l) async {
    final TextEditingController c = TextEditingController(text: m.answer);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: Corners.r(Corners.lg)),
        title: Text(m.prompt, style: AppText.h3),
        content: TextField(
          controller: c,
          maxLines: 5,
          minLines: 3,
          autofocus: true,
          style: AppText.body,
          decoration: const InputDecoration(fillColor: AppColors.surfaceMuted),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(c.text),
            child: Text(l.caregiverSaveButton),
          ),
        ],
      ),
    );
    c.dispose();
    if (result == null) return;
    final List<LifeMemory> next = <LifeMemory>[
      for (final LifeMemory x in p.memories) x.id == m.id ? x.copyWith(answer: result) : x,
    ];
    state.updateDraft(p.copyWith(memories: next));
    state.commitDraft();
  }

  // ── assets ─────────────────────────────────────────────────────────────

  Widget _assets(Patient p, AppLocalizations l) {
    if (p.assets.isEmpty) {
      return EmptyState(
        title: l.caregiverNoPhotographsTitle,
        message: l.caregiverNoPhotographsBody,
        icon: Icons.photo_library_rounded,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: l.caregiverPhotographsTitle,
          subtitle: l.caregiverPhotographsSubtitle(p.assets.length),
          dense: true,
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.78,
          ),
          itemCount: p.assets.length,
          itemBuilder: (BuildContext context, int i) {
            final MemoryAsset a = p.assets[i];
            return Column(
              children: <Widget>[
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: Corners.r(Corners.md),
                      boxShadow: AppColors.softShadow(y: 3, blur: 8),
                    ),
                    child: SceneImage(sceneId: a.sceneId, radius: Corners.md, fit: false),
                  ),
                ),
                const SizedBox(height: 6),
                Text(a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.sized(11).wght(700)),
              ],
            );
          },
        ),
      ],
    );
  }

  // ── routine ────────────────────────────────────────────────────────────

  Widget _routine(Patient p, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: l.caregiverDailyRoutineTitle,
          subtitle: l.caregiverDailyRoutineSubtitle,
          dense: true,
        ),
        MmCard(
          child: Column(
            children: <Widget>[
              for (int i = 0; i < p.routine.length; i++)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 76,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(p.routine[i].time, style: AppText.label.wght(800)),
                      ),
                    ),
                    Column(
                      children: <Widget>[
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _color(p.routine[i].kind),
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (i != p.routine.length - 1)
                          Container(width: 2, height: 46, color: AppColors.hairline),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: i == p.routine.length - 1 ? 0 : 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(p.routine[i].title, style: AppText.body.wght(700)),
                            if (p.routine[i].detail.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 2),
                              Text(p.routine[i].detail, style: AppText.bodySmall),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  static Color _color(RoutineKind k) => switch (k) {
        RoutineKind.meal => AppColors.accent,
        RoutineKind.activity => AppColors.primary,
        RoutineKind.rest => AppColors.secondary,
        RoutineKind.cognitive => AppColors.plum,
        RoutineKind.medicine => AppColors.terracotta,
        RoutineKind.social => AppColors.indigo,
      };
}
