import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/patient.dart';
import '../../../core/services/app_state.dart';
import '../../../core/services/photo_store.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
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
                          2 => _assets(p, state, l),
                          _ => _routine(p, state, l),
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
                  onPressed: () => Nav.open(context, const LifeProfileScreen()),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: l.caregiverPeopleTitle,
          subtitle: l.caregiverPeopleSubtitle,
          dense: true,
        ),
        if (p.family.isEmpty)
          EmptyState(
            title: 'Nobody added yet',
            message: 'Add the people who matter to them — the app uses these '
                'names and faces in the activities.',
            icon: Icons.groups_2_rounded,
          ),
        for (final FamilyMember f in p.family)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MmCard(
              padding: const EdgeInsets.all(14),
              onTap: () => _saveFamily(p, state, existing: f),
              child: Row(
                children: <Widget>[
                  MemoryPicture(
                    sceneId: f.sceneId,
                    photoPath: f.photoPath,
                    size: 58,
                  ),
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
                  const Icon(Icons.edit_outlined, size: 18, color: AppColors.inkMuted),
                  RoundIconButton(
                    icon: Icons.delete_outline_rounded,
                    size: 38,
                    color: AppColors.inkMuted,
                    tooltip: l.caregiverRemoveTooltip,
                    onPressed: () => _deleteFamily(f, p, state),
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

  /// Add when [existing] is null, replace in place when it is not.
  ///
  /// The People tab used to offer only a fixed list of sample relatives to
  /// add, so a real family could not be entered here at all — the one screen
  /// named after them was the one that could not hold them.
  Future<void> _saveFamily(Patient p, AppState state, {FamilyMember? existing}) async {
    final FamilyMember? edited = await editFamilyMember(context, existing: existing);
    if (edited == null) return;
    final List<FamilyMember> next = existing == null
        ? <FamilyMember>[...p.family, edited]
        : <FamilyMember>[
            for (final FamilyMember f in p.family) f.id == edited.id ? edited : f,
          ];
    state.updateDraft(p.copyWith(family: next));
    state.commitDraft();
  }

  Future<void> _deleteFamily(FamilyMember f, Patient p, AppState state) async {
    if (!await confirmDelete(context, f.name)) return;
    // The record and its photograph go together, or the documents directory
    // fills up with faces nothing points at any more.
    await PhotoStore.delete(f.photoPath);
    state.updateDraft(p.copyWith(
      family: <FamilyMember>[for (final FamilyMember x in p.family) if (x.id != f.id) x],
    ));
    state.commitDraft();
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
        if (p.memories.isEmpty)
          EmptyState(
            title: 'No memories yet',
            message: 'A question and the answer to it — the activities ask '
                'these back in their own words.',
            icon: Icons.auto_stories_rounded,
          ),
        for (final LifeMemory m in p.memories)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MmCard(
              onTap: () => _saveMemory(p, state, existing: m),
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
                      RoundIconButton(
                        icon: Icons.delete_outline_rounded,
                        size: 34,
                        color: AppColors.inkMuted,
                        tooltip: l.caregiverRemoveTooltip,
                        onPressed: () => _deleteMemory(m, p, state),
                      ),
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
        const SizedBox(height: 4),
        SoftButton(
          label: 'Add a memory',
          icon: Icons.add_rounded,
          onPressed: () => _saveMemory(p, state),
        ),
      ],
    );
  }

  /// The editor took only the answer before, so a memory could be corrected
  /// but never written — every one had to come from the onboarding.
  Future<void> _saveMemory(Patient p, AppState state, {LifeMemory? existing}) async {
    final LifeMemory? edited = await editLifeMemory(context, existing: existing);
    if (edited == null) return;
    final List<LifeMemory> next = existing == null
        ? <LifeMemory>[...p.memories, edited]
        : <LifeMemory>[
            for (final LifeMemory m in p.memories) m.id == edited.id ? edited : m,
          ];
    state.updateDraft(p.copyWith(memories: next));
    state.commitDraft();
  }

  Future<void> _deleteMemory(LifeMemory m, Patient p, AppState state) async {
    if (!await confirmDelete(context, 'this memory')) return;
    state.updateDraft(p.copyWith(
      memories: <LifeMemory>[for (final LifeMemory x in p.memories) if (x.id != m.id) x],
    ));
    state.commitDraft();
  }

  // ── photographs ────────────────────────────────────────────────────────

  Widget _assets(Patient p, AppState state, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: l.caregiverPhotographsTitle,
          subtitle: p.assets.isEmpty
              ? l.caregiverNoPhotographsBody
              : l.caregiverPhotographsSubtitle(p.assets.length),
          dense: true,
        ),
        if (p.assets.isEmpty)
          EmptyState(
            title: l.caregiverNoPhotographsTitle,
            message: l.caregiverNoPhotographsBody,
            icon: Icons.photo_library_rounded,
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemCount: p.assets.length,
            itemBuilder: (BuildContext context, int i) {
              final MemoryAsset a = p.assets[i];
              return GestureDetector(
                onLongPress: () => _deleteAsset(a, p, state),
                child: Pressable(
                  onTap: () => _saveAsset(p, state, existing: a),
                  child: Column(
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: Corners.r(Corners.md),
                          boxShadow: AppColors.softShadow(y: 3, blur: 8),
                        ),
                        child: MemoryPicture(
                          sceneId: a.sceneId,
                          photoPath: a.photoPath,
                          size: 120,
                          circle: false,
                          radius: Corners.md,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                      Text(a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.sized(11).wght(700)),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: Insets.md),
        SoftButton(
          label: 'Add a picture',
          icon: Icons.add_photo_alternate_outlined,
          onPressed: () => _saveAsset(p, state),
        ),
        const SizedBox(height: 6),
        Text(
          'Tap a picture to change it, press and hold to remove it.',
          textAlign: TextAlign.center,
          style: AppText.caption.tint(AppColors.inkMuted),
        ),
      ],
    );
  }

  Future<void> _saveAsset(Patient p, AppState state, {MemoryAsset? existing}) async {
    final MemoryAsset? edited = await editMemoryAsset(context, existing: existing);
    if (edited == null) return;
    final List<MemoryAsset> next = existing == null
        ? <MemoryAsset>[...p.assets, edited]
        : <MemoryAsset>[
            for (final MemoryAsset a in p.assets) a.id == edited.id ? edited : a,
          ];
    state.updateDraft(p.copyWith(assets: next));
    state.commitDraft();
  }

  Future<void> _deleteAsset(MemoryAsset a, Patient p, AppState state) async {
    if (!await confirmDelete(context, a.title)) return;
    await PhotoStore.delete(a.photoPath);
    state.updateDraft(p.copyWith(
      assets: <MemoryAsset>[for (final MemoryAsset x in p.assets) if (x.id != a.id) x],
    ));
    state.commitDraft();
  }

  // ── routine ────────────────────────────────────────────────────────────

  Widget _routine(Patient p, AppState state, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: l.caregiverDailyRoutineTitle,
          subtitle: l.caregiverDailyRoutineSubtitle,
          dense: true,
        ),
        if (p.routine.isEmpty)
          EmptyState(
            title: 'No routine yet',
            message: 'Lay out an ordinary day and the reminders and activities '
                'follow it.',
            icon: Icons.schedule_rounded,
          )
        else
          MmCard(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < p.routine.length; i++)
                  GestureDetector(
                    onLongPress: () => _deleteRoutine(i, p, state),
                    child: Pressable(
                      onTap: () => _saveRoutine(p, state, index: i),
                      child: Row(
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
                                color: routineColor(p.routine[i].kind),
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
                            padding:
                                EdgeInsets.only(bottom: i == p.routine.length - 1 ? 0 : 18),
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
                          const Icon(Icons.edit_outlined,
                              size: 16, color: AppColors.inkMuted),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: Insets.md),
        SoftButton(
          label: 'Add to the day',
          icon: Icons.add_rounded,
          onPressed: () => _saveRoutine(p, state),
        ),
        const SizedBox(height: 6),
        Text(
          'Tap a step to change it, press and hold to remove it.',
          textAlign: TextAlign.center,
          style: AppText.caption.tint(AppColors.inkMuted),
        ),
      ],
    );
  }

  /// Routine items carry no id, so they are addressed by position. Kept
  /// sorted by time after every write, or a step added at 7am would sit at
  /// the bottom of the evening.
  Future<void> _saveRoutine(Patient p, AppState state, {int? index}) async {
    final RoutineItem? edited = await editRoutineItem(
      context,
      existing: index == null ? null : p.routine[index],
    );
    if (edited == null) return;
    final List<RoutineItem> next = <RoutineItem>[...p.routine];
    if (index == null) {
      next.add(edited);
    } else {
      next[index] = edited;
    }
    next.sort((RoutineItem a, RoutineItem b) => _minutes(a.time).compareTo(_minutes(b.time)));
    state.updateDraft(p.copyWith(routine: next));
    state.commitDraft();
  }

  Future<void> _deleteRoutine(int index, Patient p, AppState state) async {
    if (!await confirmDelete(context, p.routine[index].title)) return;
    final List<RoutineItem> next = <RoutineItem>[...p.routine]..removeAt(index);
    state.updateDraft(p.copyWith(routine: next));
    state.commitDraft();
  }

  /// "7:30 AM" → 450. Anything unparseable sorts to the end rather than
  /// throwing on a value some other screen wrote.
  static int _minutes(String label) {
    final RegExpMatch? m = RegExp(r'(\d{1,2}):(\d{2})\s*([AaPp])?').firstMatch(label);
    if (m == null) return 24 * 60;
    int hour = int.parse(m.group(1)!);
    final int minute = int.parse(m.group(2)!);
    final String? half = m.group(3)?.toUpperCase();
    if (half == 'P' && hour != 12) hour += 12;
    if (half == 'A' && hour == 12) hour = 0;
    return hour * 60 + minute;
  }


}
