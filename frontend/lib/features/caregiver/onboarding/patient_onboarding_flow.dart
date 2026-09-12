import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/patient.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/celebration.dart';
import '../../../core/widgets/companion.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/motifs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/mock/mock_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../patient/patient_shell.dart';

/// Six-step onboarding run by the caregiver.
///
/// This is where personalisation is *created*: every answer here becomes
/// content in the patient's activities, so the flow is written to feel like
/// telling someone about a person, not like filling in a medical form.
class PatientOnboardingFlow extends StatefulWidget {
  const PatientOnboardingFlow({super.key});

  @override
  State<PatientOnboardingFlow> createState() => _PatientOnboardingFlowState();
}

class _PatientOnboardingFlowState extends State<PatientOnboardingFlow> {
  final PageController _pages = PageController();
  int _step = 0;
  static const int _totalSteps = 6;

  // ── draft fields ───────────────────────────────────────────────────────
  final TextEditingController _name = TextEditingController(text: 'Aama Devi');
  final TextEditingController _short = TextEditingController(text: 'Aama');
  final TextEditingController _location = TextEditingController(text: 'Jorhat, Assam');
  final TextEditingController _phone = TextEditingController(text: '+919876543210');
  int _age = 72;
  String _language = 'Assamese';
  String _portrait = 'portrait_aama';

  final List<FamilyMember> _family = <FamilyMember>[];
  final Map<String, TextEditingController> _memories = <String, TextEditingController>{};
  final Set<String> _assetIds = <String>{};
  final List<RoutineItem> _routine = List<RoutineItem>.from(MockData.routine);

  AppLocalizations get _l => AppLocalizations.of(context);

  // The canonical (English) values actually stored in `_language` and, on
  // commit, `Patient.language` — downstream code (`VoiceLanguageX
  // .fromPatientLanguage`, `LocaleController.fromPatientLanguage`) matches
  // against these English names regardless of interface language, so only
  // the *displayed* chip label may change with locale; the stored value
  // must not.
  static const List<String> _languages = <String>[
    'Assamese', 'Bodo', 'Meiteilon', 'Khasi', 'Mizo', 'Nagamese', 'Bengali', 'Hindi',
  ];

  String _languageLabel(String canonical) => switch (canonical) {
        'Assamese' => _l.languageAssamese,
        'Hindi' => _l.languageHindi,
        'Bodo' => _l.caregiverLangBodo,
        'Meiteilon' => _l.caregiverLangMeiteilon,
        'Khasi' => _l.caregiverLangKhasi,
        'Mizo' => _l.caregiverLangMizo,
        'Nagamese' => _l.caregiverLangNagamese,
        'Bengali' => _l.caregiverLangBengali,
        _ => canonical,
      };

  @override
  void initState() {
    super.initState();
    for (final LifeMemory m in MockData.memories) {
      _memories[m.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    _short.dispose();
    _location.dispose();
    _phone.dispose();
    for (final TextEditingController c in _memories.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── navigation ─────────────────────────────────────────────────────────

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _name.text.trim().isNotEmpty;
      case 1:
        return _family.isNotEmpty;
      case 2:
        return _memories.values.any((TextEditingController c) => c.text.trim().isNotEmpty);
      case 3:
        return _assetIds.isNotEmpty;
      default:
        return true;
    }
  }

  void _next() {
    if (_step == _totalSteps - 1) {
      _commit();
      return;
    }
    setState(() => _step++);
    _pages.animateToPage(_step, duration: Motion.normal, curve: Motion.enter);
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _step--);
    _pages.animateToPage(_step, duration: Motion.normal, curve: Motion.enter);
  }

  void _commit() {
    final AppState state = AppScope.read(context);
    final Patient p = Patient(
      id: 'p_aama',
      name: _name.text.trim(),
      shortName: _short.text.trim().isEmpty ? _name.text.trim().split(' ').first : _short.text.trim(),
      age: _age,
      location: _location.text.trim(),
      language: _language,
      occupation: _valueOf('m_work', fallback: 'Weaver'),
      favouriteActivity: _valueOf('m_activity', fallback: 'Traditional weaving'),
      favouriteFood: _valueOf('m_food', fallback: 'Pitha'),
      tradition: _valueOf('m_tradition', fallback: 'Magh Bihu'),
      portraitScene: _portrait,
      family: _family,
      memories: <LifeMemory>[
        for (final LifeMemory m in MockData.memories)
          m.copyWith(
            answer: _memories[m.id]!.text.trim().isEmpty
                ? m.answer
                : _memories[m.id]!.text.trim(),
          ),
      ],
      assets: MockData.assets
          .where((MemoryAsset a) => _assetIds.contains(a.id))
          .toList(growable: false),
      routine: _routine,
      joinedOn: _l.caregiverProfileCreatedToday,
      phoneNumber: _phone.text.trim(),
    );
    state.updateDraft(p);
    state.commitDraft();
    Nav.replace(context, const _OnboardingCompleteScreen());
  }

  String _valueOf(String id, {required String fallback}) {
    final String v = _memories[id]?.text.trim() ?? '';
    if (v.isEmpty) return fallback;
    // Keep the first clause so the value reads well in a chip.
    final String first = v.split(RegExp(r'[.,]')).first.trim();
    return first.isEmpty ? fallback : first;
  }

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: MotifBackground(
        opacity: 0.04,
        washColors: <Color>[
          AppColors.primaryTint.withValues(alpha: 0.85),
          AppColors.background.withValues(alpha: 0),
        ],
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _header(),
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    _stepIdentity(),
                    _stepFamily(),
                    _stepMemories(),
                    _stepAssets(),
                    _stepRoutine(),
                    _stepReview(),
                  ],
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final List<String> titles = <String>[
      _l.caregiverStepTitleIdentity,
      _l.caregiverStepTitleFamily,
      _l.caregiverMemoriesTitle,
      _l.caregiverPhotographsTitle,
      _l.caregiverStepTitleRoutine,
      _l.caregiverStepTitleReady,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 8, Insets.gutter, Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              RoundIconButton(
                icon: Icons.arrow_back_rounded,
                size: 44,
                onPressed: _back,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(_l.caregiverStepLabel(_step + 1, _totalSteps), style: AppText.overline),
                    const SizedBox(height: 3),
                    Text(titles[_step], style: AppText.h2),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              for (int i = 0; i < _totalSteps; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == _totalSteps - 1 ? 0 : 6),
                    child: AnimatedContainer(
                      duration: Motion.normal,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i <= _step
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: Corners.r(4),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 8, Insets.gutter, 12),
      child: Row(
        children: <Widget>[
          if (_step > 0) ...<Widget>[
            Expanded(
              flex: 2,
              child: BigButton(
                label: _l.caregiverBackButton,
                color: AppColors.inkSoft,
                outlined: true,
                height: 60,
                onPressed: _back,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 3,
            child: BigButton(
              label: _step == _totalSteps - 1
                  ? _l.caregiverCreateCompanionButton
                  : _l.actionContinue,
              icon: _step == _totalSteps - 1
                  ? Icons.auto_awesome_rounded
                  : Icons.arrow_forward_rounded,
              height: 60,
              onPressed: _canContinue ? _next : null,
            ),
          ),
        ],
      ),
    );
  }

  EdgeInsets get _pagePad =>
      const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 20);

  // ── step 1: identity ───────────────────────────────────────────────────

  Widget _stepIdentity() {
    return ListView(
      padding: _pagePad,
      children: <Widget>[
        CompanionSpeech(
          message: _l.caregiverStep1Companion,
          state: CompanionState.happy,
          companionSize: 68,
          compact: true,
        ),
        const SizedBox(height: Insets.lg),
        MmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(_l.caregiverHerPhotographLabel, style: AppText.overline),
              const SizedBox(height: 12),
              SizedBox(
                height: 92,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    for (final String s in Scenes.people)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Pressable(
                          onTap: () => setState(() => _portrait = s),
                          child: AnimatedContainer(
                            duration: Motion.quick,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _portrait == s
                                    ? AppColors.primary
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: SceneImage(sceneId: s, size: 76, circle: true),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(_l.caregiverDemoPhotosNote,
                  style: AppText.caption),
              const SizedBox(height: Insets.lg),
              _Field(label: _l.caregiverFieldFullName, controller: _name, hint: 'Aama Devi'),
              const SizedBox(height: 14),
              _Field(
                label: _l.caregiverFieldShortName,
                controller: _short,
                hint: 'Aama',
              ),
              const SizedBox(height: 14),
              _Field(label: _l.caregiverFieldPhone, controller: _phone, hint: '+919876543210'),
              const SizedBox(height: 14),
              Text(_l.caregiverAgeLabel, style: AppText.overline),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Slider(
                      value: _age.toDouble(),
                      min: 55,
                      max: 95,
                      divisions: 40,
                      activeColor: AppColors.primary,
                      onChanged: (double v) => setState(() => _age = v.round()),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: Corners.r(Corners.pill),
                    ),
                    child: Text(_l.caregiverAgeYears(_age),
                        style: AppText.body.wght(800).tint(AppColors.primaryDeep)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Field(label: _l.caregiverFieldLocation, controller: _location, hint: 'Jorhat, Assam'),
              const SizedBox(height: 16),
              Text(_l.caregiverPreferredLanguageLabel, style: AppText.overline),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final String lang in _languages)
                    _SelectChip(
                      label: _languageLabel(lang),
                      selected: _language == lang,
                      onTap: () => setState(() => _language = lang),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── step 2: family ─────────────────────────────────────────────────────

  Widget _stepFamily() {
    final List<FamilyMember> suggestions = MockData.family
        .where((FamilyMember m) => !_family.any((FamilyMember f) => f.id == m.id))
        .toList();

    return ListView(
      padding: _pagePad,
      children: <Widget>[
        CompanionSpeech(
          message: _l.caregiverStep2Companion,
          state: CompanionState.listening,
          companionSize: 68,
          compact: true,
        ),
        const SizedBox(height: Insets.lg),
        if (_family.isNotEmpty) ...<Widget>[
          Text(_l.caregiverAddedLabel, style: AppText.overline),
          const SizedBox(height: 10),
          for (final FamilyMember f in _family)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MmCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <Widget>[
                    SceneImage(sceneId: f.sceneId, size: 54, circle: true),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(f.name, style: AppText.h3),
                          const SizedBox(height: 2),
                          Text(f.relation, style: AppText.bodySmall),
                        ],
                      ),
                    ),
                    RoundIconButton(
                      icon: Icons.close_rounded,
                      size: 38,
                      color: AppColors.inkMuted,
                      onPressed: () => setState(() => _family.remove(f)),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: Insets.md),
        ],
        if (suggestions.isNotEmpty) ...<Widget>[
          Text(_l.caregiverTapToAddLabel, style: AppText.overline),
          const SizedBox(height: 10),
          for (final FamilyMember f in suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MmCard(
                padding: const EdgeInsets.all(12),
                onTap: () => setState(() => _family.add(f)),
                child: Row(
                  children: <Widget>[
                    SceneImage(sceneId: f.sceneId, size: 54, circle: true),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(f.name, style: AppText.h3),
                          const SizedBox(height: 2),
                          Text(f.relation, style: AppText.bodySmall),
                          if (f.note.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(f.note, style: AppText.caption),
                          ],
                        ],
                      ),
                    ),
                    const SoftIcon(
                      icon: Icons.add_rounded,
                      color: AppColors.primary,
                      size: 38,
                    ),
                  ],
                ),
              ),
            ),
        ] else
          MmCard(
            color: AppColors.successTint,
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            child: Row(
              children: <Widget>[
                const Icon(Icons.check_circle_rounded, color: AppColors.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_l.caregiverEveryoneAddedMessage,
                      style: AppText.body.wght(700).tint(AppColors.success)),
                ),
              ],
            ),
          ),
        const SizedBox(height: Insets.md),
        if (_family.isEmpty)
          SoftButton(
            label: _l.caregiverAddEveryoneButton,
            icon: Icons.group_add_rounded,
            onPressed: () => setState(() {
              _family
                ..clear()
                ..addAll(MockData.family);
            }),
          ),
      ],
    );
  }

  // ── step 3: memories ───────────────────────────────────────────────────

  Widget _stepMemories() {
    return ListView(
      padding: _pagePad,
      children: <Widget>[
        CompanionSpeech(
          message: _l.caregiverStep3Companion,
          state: CompanionState.thinking,
          companionSize: 68,
          compact: true,
        ),
        const SizedBox(height: Insets.md),
        Align(
          alignment: Alignment.centerLeft,
          child: SoftButton(
            label: _l.caregiverFillSuggestedButton,
            icon: Icons.auto_fix_high_rounded,
            onPressed: () => setState(() {
              for (final LifeMemory m in MockData.memories) {
                _memories[m.id]!.text = m.answer;
              }
            }),
          ),
        ),
        const SizedBox(height: Insets.lg),
        for (final LifeMemory m in MockData.memories)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PillTag(
                        label: m.category, color: AppColors.primary, dense: true),
                  ),
                  const SizedBox(height: 10),
                  Text(m.prompt, style: AppText.h3.sized(18)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _memories[m.id],
                    maxLines: 3,
                    minLines: 2,
                    style: AppText.body,
                    decoration: InputDecoration(
                      hintText: m.answer,
                      fillColor: AppColors.surfaceMuted,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── step 4: assets ─────────────────────────────────────────────────────

  Widget _stepAssets() {
    return ListView(
      padding: _pagePad,
      children: <Widget>[
        CompanionSpeech(
          message: _l.caregiverStep4Companion,
          state: CompanionState.happy,
          companionSize: 68,
          compact: true,
        ),
        const SizedBox(height: Insets.md),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(_l.caregiverAssetsSelectedCount(_assetIds.length, MockData.assets.length),
                  style: AppText.label),
            ),
            SoftButton(
              label: _assetIds.length == MockData.assets.length
                  ? _l.caregiverClearAllButton
                  : _l.caregiverSelectAllButton,
              icon: Icons.select_all_rounded,
              onPressed: () => setState(() {
                if (_assetIds.length == MockData.assets.length) {
                  _assetIds.clear();
                } else {
                  _assetIds
                    ..clear()
                    ..addAll(MockData.assets.map((MemoryAsset a) => a.id));
                }
              }),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.8,
          ),
          itemCount: MockData.assets.length,
          itemBuilder: (BuildContext context, int i) {
            final MemoryAsset a = MockData.assets[i];
            final bool on = _assetIds.contains(a.id);
            return Pressable(
              onTap: () => setState(() {
                if (!_assetIds.remove(a.id)) _assetIds.add(a.id);
              }),
              child: AnimatedContainer(
                duration: Motion.quick,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: on ? AppColors.primaryTint : Colors.white,
                  borderRadius: Corners.r(Corners.md),
                  border: Border.all(
                    color: on ? AppColors.primary : AppColors.hairline,
                    width: on ? 2.2 : 1.2,
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child: SceneImage(sceneId: a.sceneId, radius: 10, fit: false),
                          ),
                          if (on)
                            const Positioned(
                              right: 4,
                              top: 4,
                              child: CircleAvatar(
                                radius: 11,
                                backgroundColor: AppColors.primary,
                                child: Icon(Icons.check_rounded,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      a.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.sized(11).wght(700),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── step 5: routine ────────────────────────────────────────────────────

  Widget _stepRoutine() {
    return ListView(
      padding: _pagePad,
      children: <Widget>[
        CompanionSpeech(
          message: _l.caregiverStep5Companion,
          state: CompanionState.encouraging,
          companionSize: 68,
          compact: true,
        ),
        const SizedBox(height: Insets.lg),
        MmCard(
          child: Column(
            children: <Widget>[
              for (int i = 0; i < _routine.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i == _routine.length - 1 ? 0 : 12),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 84,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: Corners.r(Corners.sm),
                        ),
                        child: Text(_routine[i].time,
                            textAlign: TextAlign.center, style: AppText.caption.wght(800)),
                      ),
                      const SizedBox(width: 12),
                      SoftIcon(
                        icon: _routineIcon(_routine[i].kind),
                        color: _routineColor(_routine[i].kind),
                        size: 38,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(_routine[i].title, style: AppText.body.wght(700)),
                            if (_routine[i].detail.isNotEmpty)
                              Text(_routine[i].detail, style: AppText.caption),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                        color: AppColors.inkMuted,
                        onPressed: () => setState(() => _routine.removeAt(i)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        if (_routine.length < MockData.routine.length)
          SoftButton(
            label: _l.caregiverRestoreRoutineButton,
            icon: Icons.restore_rounded,
            onPressed: () => setState(() {
              _routine
                ..clear()
                ..addAll(MockData.routine);
            }),
          ),
      ],
    );
  }

  static IconData _routineIcon(RoutineKind k) => switch (k) {
        RoutineKind.meal => Icons.restaurant_rounded,
        RoutineKind.activity => Icons.self_improvement_rounded,
        RoutineKind.rest => Icons.airline_seat_flat_rounded,
        RoutineKind.cognitive => Icons.psychology_alt_rounded,
        RoutineKind.medicine => Icons.medication_liquid_rounded,
        RoutineKind.social => Icons.phone_in_talk_rounded,
      };

  static Color _routineColor(RoutineKind k) => switch (k) {
        RoutineKind.meal => AppColors.accent,
        RoutineKind.activity => AppColors.primary,
        RoutineKind.rest => AppColors.secondary,
        RoutineKind.cognitive => AppColors.plum,
        RoutineKind.medicine => AppColors.terracotta,
        RoutineKind.social => AppColors.indigo,
      };

  // ── step 6: review ─────────────────────────────────────────────────────

  Widget _stepReview() {
    final String name = _short.text.trim().isEmpty ? _l.caregiverSheFallback : _short.text.trim();
    return ListView(
      padding: _pagePad,
      children: <Widget>[
        MmCard(
          shadow: AppColors.liftShadow(),
          child: Column(
            children: <Widget>[
              SceneImage(
                sceneId: _portrait,
                size: 108,
                circle: true,
                borderColor: Colors.white,
                borderWidth: 4,
              ),
              const SizedBox(height: 12),
              Text(_name.text.trim(), style: AppText.h1.sized(26)),
              const SizedBox(height: 6),
              Text(
                  _l.caregiverReviewSummary(
                      _age, _location.text.trim(), _languageLabel(_language)),
                  style: AppText.bodySmall),
              const SizedBox(height: Insets.md),
              const WovenStrip(height: 10, opacity: 0.6),
              const SizedBox(height: Insets.md),
              Wrap(
                alignment: WrapAlignment.spaceAround,
                spacing: 10,
                runSpacing: 14,
                children: <Widget>[
                  _ReviewStat(value: '${_family.length}', label: _l.caregiverTabPeople),
                  _ReviewStat(
                      value: '${_memories.values.where((TextEditingController c) => c.text.trim().isNotEmpty).length}',
                      label: _l.caregiverTabMemories),
                  _ReviewStat(value: '${_assetIds.length}', label: _l.caregiverTabPhotographs),
                  _ReviewStat(value: '${_routine.length}', label: _l.caregiverTabRoutine),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),
        SectionHeader(
          title: _l.caregiverWhatThisChangesTitle,
          icon: Icons.auto_awesome_rounded,
          subtitle: _l.caregiverWhatThisChangesSubtitle,
          dense: true,
        ),
        MmCard(
          color: AppColors.primaryTint,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final String line in <String>[
                if (_family.isNotEmpty)
                  _l.caregiverReviewLineFamily(name, _family.first.name),
                if (_memories['m_work']!.text.contains('eav'))
                  _l.caregiverReviewLineWeaving,
                if (_memories['m_food']!.text.isNotEmpty)
                  _l.caregiverReviewLineCooking,
                _l.caregiverReviewLineInstruments,
                _l.caregiverReviewLineLanguage(_languageLabel(_language)),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.check_rounded, size: 19, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(line,
                            style: AppText.body.wght(600).tint(AppColors.primaryDeep)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewStat extends StatelessWidget {
  const _ReviewStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: Column(
        children: <Widget>[
          Text(value, style: AppText.stat.tint(AppColors.primary)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller, required this.hint});
  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: AppText.overline),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: AppText.bodyLarge,
          decoration: InputDecoration(hintText: hint, fillColor: AppColors.surfaceMuted),
        ),
      ],
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: Corners.r(Corners.pill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.hairline,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppText.body
              .wght(selected ? 800 : 600)
              .tint(selected ? Colors.white : AppColors.ink),
        ),
      ),
    );
  }
}

/// "Aama's companion is ready." — the hand-off into the patient experience.
class _OnboardingCompleteScreen extends StatelessWidget {
  const _OnboardingCompleteScreen();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final String name = state.patient.shortName;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          MotifBackground(
            opacity: 0.05,
            washColors: <Color>[
              AppColors.primaryTint.withValues(alpha: 0.9),
              AppColors.background.withValues(alpha: 0),
            ],
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Insets.gutter),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const FadeInUp(
                          child: Companion(state: CompanionState.celebrating, size: 190),
                        ),
                        const SizedBox(height: Insets.md),
                        FadeInUp(
                          delayMs: 80,
                          child: Text(
                            l.caregiverCompanionReadyTitle(name),
                            textAlign: TextAlign.center,
                            style: AppText.hero.sized(30),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FadeInUp(
                          delayMs: 120,
                          child: Text(
                            l.caregiverCompanionReadyBody,
                            textAlign: TextAlign.center,
                            style: AppText.bodyLarge.tint(AppColors.inkSoft),
                          ),
                        ),
                        const SizedBox(height: Insets.xl),
                        FadeInUp(
                          delayMs: 160,
                          child: BigButton(
                            label: l.caregiverOpenHerExperienceTitle,
                            icon: Icons.arrow_forward_rounded,
                            onPressed: () {
                              state.setRole(AppRole.patient);
                              Nav.push(context, const PatientShell());
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        FadeInUp(
                          delayMs: 200,
                          child: BigButton(
                            label: l.caregiverBackToDashboardButton,
                            color: AppColors.inkSoft,
                            outlined: true,
                            height: 60,
                            onPressed: () {
                              state.setRole(AppRole.caregiver);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Positioned.fill(child: ConfettiOverlay(seed: 11)),
        ],
      ),
    );
  }
}
