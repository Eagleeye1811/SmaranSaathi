import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/patient.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../intake/intake_kit.dart';

/// Who the person actually is, as opposed to what they can no longer do.
///
/// The clinical onboarding produces a record. This produces a *person*: their
/// picture, the people whose names the companion should use, the stories they
/// like telling, the songs and the food. None of it is decoration — the
/// activities are assembled from exactly these answers, which is why a fresh
/// profile felt hollow until this screen existed.
///
/// Deliberately editable and re-openable rather than a one-shot wizard. A life
/// is not something a caregiver can finish describing in one sitting on the
/// day they install an app, and the most useful details arrive weeks later.
class LifeProfileScreen extends StatefulWidget {
  const LifeProfileScreen({super.key});

  @override
  State<LifeProfileScreen> createState() => _LifeProfileScreenState();
}

class _LifeProfileScreenState extends State<LifeProfileScreen> {
  late final AppState _state = AppScope.read(context);

  late final TextEditingController _where;
  late final TextEditingController _music;
  late final TextEditingController _food;
  late final TextEditingController _festival;

  late String _portrait;
  late List<FamilyMember> _family;
  late List<LifeMemory> _memories;

  /// The five illustrated portraits the app ships. Real photographs are what
  /// a family would reach for first; that needs an image picker and somewhere
  /// to keep the bytes, neither of which exists yet, so this is the honest
  /// interim — pick the one that looks most like them.
  static const List<String> _portraits = <String>[
    'portrait_aama',
    'portrait_priya',
    'portrait_aarav',
    'portrait_bhaskar',
    'portrait_neighbour',
  ];

  @override
  void initState() {
    super.initState();
    final Patient p = _state.patient;
    _where = TextEditingController(text: p.location);
    _music = TextEditingController(text: p.favouriteMusic);
    _food = TextEditingController(text: p.favouriteFood);
    _festival = TextEditingController(text: p.tradition);
    _portrait = _portraits.contains(p.portraitScene) ? p.portraitScene : _portraits.first;
    _family = List<FamilyMember>.from(p.family);
    _memories = List<LifeMemory>.from(p.memories);
  }

  @override
  void dispose() {
    _where.dispose();
    _music.dispose();
    _food.dispose();
    _festival.dispose();
    super.dispose();
  }

  void _save() {
    final AppLocalizations l = AppLocalizations.of(context);
    _state.saveLifeProfile(
      portraitScene: _portrait,
      location: _where.text.trim(),
      favouriteMusic: _music.text.trim(),
      favouriteFood: _food.text.trim(),
      tradition: _festival.text.trim(),
      family: _family,
      memories: _memories,
    );
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l.lifeSaved)));
  }

  Future<void> _addPerson() async {
    final FamilyMember? added = await showModalBottomSheet<FamilyMember>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PersonSheet(),
    );
    if (added != null) setState(() => _family = <FamilyMember>[..._family, added]);
  }

  Future<void> _addMemory() async {
    final LifeMemory? added = await showModalBottomSheet<LifeMemory>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _MemorySheet(),
    );
    if (added != null) setState(() => _memories = <LifeMemory>[..._memories, added]);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(l.lifeTitle, style: AppText.h3),
      ),
      bottomNavigationBar: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.md, Insets.gutter, Insets.md),
        child: SafeArea(
          top: false,
          child: BigButton(label: l.lifeSave, icon: Icons.check_rounded, onPressed: _save),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.xl),
        children: <Widget>[
          Text(l.lifeSubtitle, style: AppText.bodySmall.copyWith(height: 1.5)),
          const SizedBox(height: Insets.lg),

          QuestionLabel(l.lifePhotoLabel, hint: l.lifePhotoHint),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _portraits.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (BuildContext context, int i) {
                final String id = _portraits[i];
                final bool on = _portrait == id;
                return Pressable(
                  onTap: () => setState(() => _portrait = id),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: on ? AppColors.primary : AppColors.hairline,
                        width: on ? 3 : 1.4,
                      ),
                    ),
                    child: SceneImage(sceneId: id, size: 74, circle: true),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: Insets.lg),

          IntakeField(
            label: l.lifeWhereLabel,
            hint: l.lifeWhereHint,
            controller: _where,
            onChanged: () {},
          ),

          QuestionLabel(l.lifeFamilyLabel, hint: l.lifeFamilyHint),
          if (_family.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: Text(l.lifeNothingYet, style: AppText.caption),
            ),
          for (int i = 0; i < _family.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: MmCard(
                padding: const EdgeInsets.all(12),
                child: ListRow(
                  leading: SceneImage(sceneId: _family[i].sceneId, size: 44, circle: true),
                  title: _family[i].name,
                  subtitle: _family[i].livesWithPatient
                      ? '${_family[i].relation} · ${l.lifeLivesWith}'
                      : _family[i].relation,
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.inkMuted,
                    onPressed: () => setState(() => _family = <FamilyMember>[
                          for (int j = 0; j < _family.length; j++)
                            if (j != i) _family[j],
                        ]),
                  ),
                ),
              ),
            ),
          SoftButton(
            label: l.lifeAddPerson,
            icon: Icons.person_add_alt_rounded,
            onPressed: _addPerson,
          ),
          const SizedBox(height: Insets.lg),

          QuestionLabel(l.lifeMemoriesLabel, hint: l.lifeMemoriesHint),
          if (_memories.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: Text(l.lifeNothingYet, style: AppText.caption),
            ),
          for (int i = 0; i < _memories.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: MmCard(
                padding: const EdgeInsets.all(12),
                child: ListRow(
                  leading: const SoftIcon(icon: Icons.auto_stories_rounded, size: 44),
                  title: _memories[i].category,
                  subtitle: _memories[i].answer,
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.inkMuted,
                    onPressed: () => setState(() => _memories = <LifeMemory>[
                          for (int j = 0; j < _memories.length; j++)
                            if (j != i) _memories[j],
                        ]),
                  ),
                ),
              ),
            ),
          SoftButton(label: l.lifeAddMemory, icon: Icons.add_rounded, onPressed: _addMemory),
          const SizedBox(height: Insets.lg),

          IntakeField(
            label: l.lifeMusicLabel,
            hint: l.lifeMusicHint,
            controller: _music,
            onChanged: () {},
          ),
          IntakeField(
            label: l.lifeFoodLabel,
            hint: l.lifeFoodHint,
            controller: _food,
            onChanged: () {},
          ),
          IntakeField(
            label: l.lifeFestivalLabel,
            hint: l.lifeFestivalHint,
            controller: _festival,
            onChanged: () {},
          ),
          WhyWeAsk(l.lifeWhyItMatters, icon: Icons.favorite_border_rounded),
        ],
      ),
    );
  }
}

/// Adding one person. A sheet rather than a route: it is three fields, and
/// pushing a screen for three fields loses the list you were building.
class _PersonSheet extends StatefulWidget {
  const _PersonSheet();

  @override
  State<_PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends State<_PersonSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _relation = TextEditingController();
  String _scene = 'portrait_priya';
  bool _livesWith = false;

  static const List<String> _scenes = <String>[
    'portrait_priya',
    'portrait_aarav',
    'portrait_bhaskar',
    'portrait_neighbour',
    'portrait_aama',
  ];

  @override
  void dispose() {
    _name.dispose();
    _relation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool valid = _name.text.trim().isNotEmpty && _relation.text.trim().isNotEmpty;

    return _SheetShell(
      title: l.lifeAddPerson,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          IntakeField(
            label: l.lifePersonName,
            controller: _name,
            onChanged: () => setState(() {}),
          ),
          IntakeField(
            label: l.lifePersonRelation,
            hint: l.lifePersonRelationHint,
            controller: _relation,
            onChanged: () => setState(() {}),
          ),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _scenes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (BuildContext context, int i) {
                final bool on = _scene == _scenes[i];
                return Pressable(
                  onTap: () => setState(() => _scene = _scenes[i]),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: on ? AppColors.primary : AppColors.hairline,
                        width: on ? 3 : 1.4,
                      ),
                    ),
                    child: SceneImage(sceneId: _scenes[i], size: 58, circle: true),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: Insets.sm),
          ChoiceTile(
            label: l.lifeLivesWith,
            selected: _livesWith,
            multiple: true,
            onTap: () => setState(() => _livesWith = !_livesWith),
          ),
          const SizedBox(height: Insets.sm),
          BigButton(
            label: l.lifeAddPerson,
            icon: Icons.check_rounded,
            onPressed: valid
                ? () => Navigator.of(context).pop(FamilyMember(
                      id: 'fam_${DateTime.now().microsecondsSinceEpoch}',
                      name: _name.text.trim(),
                      relation: _relation.text.trim(),
                      sceneId: _scene,
                      livesWithPatient: _livesWith,
                    ))
                : null,
          ),
        ],
      ),
    );
  }
}

/// Adding one memory. The category doubles as the prompt the story activity
/// later puts in front of the person, so it is free text rather than a fixed
/// list — a life does not come in six categories.
class _MemorySheet extends StatefulWidget {
  const _MemorySheet();

  @override
  State<_MemorySheet> createState() => _MemorySheetState();
}

class _MemorySheetState extends State<_MemorySheet> {
  final TextEditingController _category = TextEditingController();
  final TextEditingController _answer = TextEditingController();

  @override
  void dispose() {
    _category.dispose();
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool valid = _category.text.trim().isNotEmpty && _answer.text.trim().isNotEmpty;

    return _SheetShell(
      title: l.lifeAddMemory,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          IntakeField(
            label: l.lifeMemoriesLabel,
            controller: _category,
            onChanged: () => setState(() {}),
          ),
          IntakeField(
            label: l.lifeMemoryAnswer,
            controller: _answer,
            lines: 3,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: Insets.sm),
          BigButton(
            label: l.lifeAddMemory,
            icon: Icons.check_rounded,
            onPressed: valid
                ? () => Navigator.of(context).pop(LifeMemory(
                      id: 'mem_${DateTime.now().microsecondsSinceEpoch}',
                      category: _category.text.trim(),
                      prompt: _category.text.trim(),
                      answer: _answer.text.trim(),
                    ))
                : null,
          ),
        ],
      ),
    );
  }
}

/// Shared chrome for both sheets, including the keyboard inset — without it
/// the fields sit under the keyboard on a short phone, which is exactly the
/// device this app is used on.
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: Insets.md),
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: Corners.r(Corners.pill),
                  ),
                ),
              ),
              Text(title, style: AppText.h3),
              const SizedBox(height: Insets.md),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
