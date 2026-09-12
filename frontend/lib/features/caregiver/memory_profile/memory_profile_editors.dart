import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/patient.dart';
import '../../../core/services/photo_store.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../intake/intake_kit.dart';

/// Add/edit sheets for everything the memory profile holds.
///
/// One sheet per record type, each used for both creating and editing: an
/// "add" form and an "edit" form that drift apart are how a field ends up
/// settable once and never correctable. Passing `existing` fills the fields
/// in and changes the button; passing nothing starts blank.
///
/// Every sheet returns the finished record, or null when dismissed. None of
/// them touch `AppState` — the caller owns the list and the write, because
/// only the caller knows whether it is inserting or replacing.

/// The portraits a person can be drawn as.
const List<String> kPortraitScenes = <String>[
  'portrait_aama',
  'portrait_priya',
  'portrait_aarav',
  'portrait_bhaskar',
  'portrait_neighbour',
];

/// Everything else the illustrator can draw, for photographs.
const List<String> kMemoryScenes = <String>[
  'village_home',
  'tea_garden',
  'river',
  'paddy',
  'hills',
  'market',
  'weaving',
  'festival',
  'bihu',
  'japi',
  'gamosa',
  'xorai',
  'orchid',
  'rhino',
  'bamboo',
  'pitha',
  'dhol',
  'pepa',
  'gogona',
];

// ── Family ──────────────────────────────────────────────────────────────

Future<FamilyMember?> editFamilyMember(BuildContext context, {FamilyMember? existing}) {
  return showModalBottomSheet<FamilyMember>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _FamilySheet(existing: existing),
  );
}

class _FamilySheet extends StatefulWidget {
  const _FamilySheet({this.existing});

  final FamilyMember? existing;

  @override
  State<_FamilySheet> createState() => _FamilySheetState();
}

class _FamilySheetState extends State<_FamilySheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _relation =
      TextEditingController(text: widget.existing?.relation ?? '');
  late final TextEditingController _note =
      TextEditingController(text: widget.existing?.note ?? '');
  late String _scene = widget.existing?.sceneId ?? kPortraitScenes.first;
  late bool _livesWith = widget.existing?.livesWithPatient ?? false;
  late String? _photo = widget.existing?.photoPath;

  /// Fixed for the life of the sheet, so a photo picked before the record is
  /// saved still lands under the id the record will have.
  late final String _id =
      widget.existing?.id ?? 'fam_${DateTime.now().microsecondsSinceEpoch}';

  @override
  void dispose() {
    _name.dispose();
    _relation.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool valid = _name.text.trim().isNotEmpty && _relation.text.trim().isNotEmpty;
    return SheetShell(
      title: widget.existing == null ? 'Add a person' : 'Edit ${widget.existing!.name}',
      children: <Widget>[
        IntakeField(
          label: 'Their name',
          controller: _name,
          onChanged: () => setState(() {}),
        ),
        IntakeField(
          label: 'Relation',
          hint: 'Daughter, neighbour, family doctor…',
          controller: _relation,
          onChanged: () => setState(() {}),
        ),
        IntakeField(
          label: 'Anything worth remembering',
          hint: 'Calls every Sunday evening',
          controller: _note,
          lines: 2,
          onChanged: () => setState(() {}),
        ),
        PhotoPickerRow(
          id: _id,
          photoPath: _photo,
          onChanged: (String? path) => setState(() => _photo = path),
        ),
        ScenePicker(
          // Still asked for even with a photo: it is what shows if the file
          // is ever gone, and picking a face that looks a little like them
          // costs one tap.
          label: PhotoStore.exists(_photo)
              ? 'If the photo is ever missing, draw them as'
              : 'How should they be drawn?',
          scenes: kPortraitScenes,
          selected: _scene,
          circle: true,
          onSelect: (String s) => setState(() => _scene = s),
        ),
        const SizedBox(height: Insets.sm),
        ChoiceTile(
          label: 'Lives with them',
          selected: _livesWith,
          multiple: true,
          onTap: () => setState(() => _livesWith = !_livesWith),
        ),
        const SizedBox(height: Insets.md),
        BigButton(
          label: widget.existing == null ? 'Add person' : 'Save changes',
          icon: Icons.check_rounded,
          onPressed: !valid
              ? null
              : () => Navigator.of(context).pop(FamilyMember(
                    // Editing keeps the id, so the caller replaces in place
                    // rather than appending a second copy of the same person.
                    id: _id,
                    name: _name.text.trim(),
                    relation: _relation.text.trim(),
                    sceneId: _scene,
                    note: _note.text.trim(),
                    livesWithPatient: _livesWith,
                    photoPath: _photo,
                  )),
        ),
      ],
    );
  }
}

// ── Memories ────────────────────────────────────────────────────────────

Future<LifeMemory?> editLifeMemory(BuildContext context, {LifeMemory? existing}) {
  return showModalBottomSheet<LifeMemory>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _MemorySheet(existing: existing),
  );
}

class _MemorySheet extends StatefulWidget {
  const _MemorySheet({this.existing});

  final LifeMemory? existing;

  @override
  State<_MemorySheet> createState() => _MemorySheetState();
}

class _MemorySheetState extends State<_MemorySheet> {
  /// Categories the rest of the app already groups memories under. Free text
  /// as well, because a life does not fit six words.
  static const List<String> _categories = <String>[
    'Family',
    'Work',
    'Home',
    'Festivals',
    'Music',
    'Food',
  ];

  late final TextEditingController _category =
      TextEditingController(text: widget.existing?.category ?? _categories.first);
  late final TextEditingController _prompt =
      TextEditingController(text: widget.existing?.prompt ?? '');
  late final TextEditingController _answer =
      TextEditingController(text: widget.existing?.answer ?? '');

  @override
  void dispose() {
    _category.dispose();
    _prompt.dispose();
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool valid =
        _prompt.text.trim().isNotEmpty && _answer.text.trim().isNotEmpty;
    return SheetShell(
      title: widget.existing == null ? 'Add a memory' : 'Edit this memory',
      children: <Widget>[
        Text('Category', style: AppText.overline),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final String c in _categories)
              Pressable(
                onTap: () => setState(() => _category.text = c),
                child: AnimatedContainer(
                  duration: Motion.quick,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _category.text == c
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: Corners.r(Corners.pill),
                  ),
                  child: Text(
                    c,
                    style: AppText.caption.wght(800).tint(
                        _category.text == c ? Colors.white : AppColors.primary),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        IntakeField(
          label: 'What is the question?',
          hint: 'Where did you grow up?',
          controller: _prompt,
          onChanged: () => setState(() {}),
        ),
        IntakeField(
          label: 'What is the answer?',
          hint: 'In a village outside Jorhat, by the river.',
          controller: _answer,
          lines: 4,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: Insets.md),
        BigButton(
          label: widget.existing == null ? 'Add memory' : 'Save changes',
          icon: Icons.check_rounded,
          onPressed: !valid
              ? null
              : () => Navigator.of(context).pop(LifeMemory(
                    id: widget.existing?.id ??
                        'mem_${DateTime.now().microsecondsSinceEpoch}',
                    category: _category.text.trim().isEmpty
                        ? _categories.first
                        : _category.text.trim(),
                    prompt: _prompt.text.trim(),
                    answer: _answer.text.trim(),
                  )),
        ),
      ],
    );
  }
}

// ── Photographs ─────────────────────────────────────────────────────────

Future<MemoryAsset?> editMemoryAsset(BuildContext context, {MemoryAsset? existing}) {
  return showModalBottomSheet<MemoryAsset>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _AssetSheet(existing: existing),
  );
}

class _AssetSheet extends StatefulWidget {
  const _AssetSheet({this.existing});

  final MemoryAsset? existing;

  @override
  State<_AssetSheet> createState() => _AssetSheetState();
}

class _AssetSheetState extends State<_AssetSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _caption =
      TextEditingController(text: widget.existing?.caption ?? '');
  late final TextEditingController _year =
      TextEditingController(text: widget.existing?.year ?? '');
  late String _scene = widget.existing?.sceneId ?? kMemoryScenes.first;
  late MemoryAssetKind _kind = widget.existing?.kind ?? MemoryAssetKind.place;
  late String? _photo = widget.existing?.photoPath;
  late final String _id =
      widget.existing?.id ?? 'asset_${DateTime.now().microsecondsSinceEpoch}';

  @override
  void dispose() {
    _title.dispose();
    _caption.dispose();
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool valid = _title.text.trim().isNotEmpty;
    return SheetShell(
      title: widget.existing == null ? 'Add a picture' : 'Edit this picture',
      children: <Widget>[
        PhotoPickerRow(
          id: _id,
          photoPath: _photo,
          onChanged: (String? path) => setState(() => _photo = path),
        ),
        IntakeField(
          label: 'What is it?',
          hint: 'The house in Jorhat',
          controller: _title,
          onChanged: () => setState(() {}),
        ),
        IntakeField(
          label: 'Caption',
          hint: 'Where the children grew up',
          controller: _caption,
          lines: 2,
          onChanged: () => setState(() {}),
        ),
        IntakeField(
          label: 'Year',
          hint: '1978',
          controller: _year,
          keyboardType: TextInputType.number,
          onChanged: () => setState(() {}),
        ),
        Text('Kind', style: AppText.overline),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final MemoryAssetKind k in MemoryAssetKind.values)
              Pressable(
                onTap: () => setState(() => _kind = k),
                child: AnimatedContainer(
                  duration: Motion.quick,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kind == k
                        ? AppColors.terracotta
                        : AppColors.terracotta.withValues(alpha: 0.08),
                    borderRadius: Corners.r(Corners.pill),
                  ),
                  child: Text(
                    k.label,
                    style: AppText.caption
                        .wght(800)
                        .tint(_kind == k ? Colors.white : AppColors.terracotta),
                  ),
                ),
              ),
          ],
        ),
        ScenePicker(
          label: PhotoStore.exists(_photo)
              ? 'If the photo is ever missing, show'
              : 'Which drawing?',
          scenes: kMemoryScenes,
          selected: _scene,
          circle: false,
          onSelect: (String s) => setState(() => _scene = s),
        ),
        const SizedBox(height: Insets.md),
        BigButton(
          label: widget.existing == null ? 'Add picture' : 'Save changes',
          icon: Icons.check_rounded,
          onPressed: !valid
              ? null
              : () => Navigator.of(context).pop(MemoryAsset(
                    id: _id,
                    title: _title.text.trim(),
                    sceneId: _scene,
                    kind: _kind,
                    caption: _caption.text.trim(),
                    year: _year.text.trim().isEmpty ? null : _year.text.trim(),
                    photoPath: _photo,
                  )),
        ),
      ],
    );
  }
}

// ── Routine ─────────────────────────────────────────────────────────────

Future<RoutineItem?> editRoutineItem(BuildContext context, {RoutineItem? existing}) {
  return showModalBottomSheet<RoutineItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _RoutineSheet(existing: existing),
  );
}

class _RoutineSheet extends StatefulWidget {
  const _RoutineSheet({this.existing});

  final RoutineItem? existing;

  @override
  State<_RoutineSheet> createState() => _RoutineSheetState();
}

class _RoutineSheetState extends State<_RoutineSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _detail =
      TextEditingController(text: widget.existing?.detail ?? '');
  late TimeOfDay _time = _parse(widget.existing?.time);
  late RoutineKind _kind = widget.existing?.kind ?? RoutineKind.activity;

  /// Stored as a display string ("7:30 AM"), so it has to be read back out.
  /// An unparseable value means a routine written by hand somewhere else —
  /// fall back to morning rather than refusing to open the editor.
  static TimeOfDay _parse(String? label) {
    if (label == null) return const TimeOfDay(hour: 8, minute: 0);
    final RegExpMatch? m =
        RegExp(r'(\d{1,2}):(\d{2})\s*([AaPp])?').firstMatch(label);
    if (m == null) return const TimeOfDay(hour: 8, minute: 0);
    int hour = int.parse(m.group(1)!);
    final int minute = int.parse(m.group(2)!);
    final String? half = m.group(3)?.toUpperCase();
    if (half == 'P' && hour != 12) hour += 12;
    if (half == 'A' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour % 24, minute: minute);
  }

  String get _label {
    final int h = _time.hourOfPeriod == 0 ? 12 : _time.hourOfPeriod;
    final String m = _time.minute.toString().padLeft(2, '0');
    return '$h:$m ${_time.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool valid = _title.text.trim().isNotEmpty;
    return SheetShell(
      title: widget.existing == null ? 'Add to the day' : 'Edit this step',
      children: <Widget>[
        Text('Time', style: AppText.overline),
        const SizedBox(height: 8),
        Pressable(
          onTap: () async {
            final TimeOfDay? picked =
                await showTimePicker(context: context, initialTime: _time);
            if (picked != null) setState(() => _time = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: Corners.r(Corners.md),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.schedule_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(_label, style: AppText.body.wght(700))),
                const Icon(Icons.edit_outlined, size: 17, color: AppColors.inkMuted),
              ],
            ),
          ),
        ),
        const SizedBox(height: Insets.md),
        IntakeField(
          label: 'What happens?',
          hint: 'Morning tea on the veranda',
          controller: _title,
          onChanged: () => setState(() {}),
        ),
        IntakeField(
          label: 'Anything to add',
          hint: 'She likes it strong, with one sugar',
          controller: _detail,
          lines: 2,
          onChanged: () => setState(() {}),
        ),
        Text('Kind', style: AppText.overline),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final RoutineKind k in RoutineKind.values)
              Pressable(
                onTap: () => setState(() => _kind = k),
                child: AnimatedContainer(
                  duration: Motion.quick,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kind == k
                        ? routineColor(k)
                        : routineColor(k).withValues(alpha: 0.10),
                    borderRadius: Corners.r(Corners.pill),
                  ),
                  child: Text(
                    routineLabel(k),
                    style: AppText.caption
                        .wght(800)
                        .tint(_kind == k ? Colors.white : routineColor(k)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Insets.md),
        BigButton(
          label: widget.existing == null ? 'Add to the day' : 'Save changes',
          icon: Icons.check_rounded,
          onPressed: !valid
              ? null
              : () => Navigator.of(context).pop(RoutineItem(
                    time: _label,
                    title: _title.text.trim(),
                    kind: _kind,
                    detail: _detail.text.trim(),
                  )),
        ),
      ],
    );
  }
}

// ── Shared ──────────────────────────────────────────────────────────────

Color routineColor(RoutineKind k) => switch (k) {
      RoutineKind.meal => AppColors.accent,
      RoutineKind.activity => AppColors.primary,
      RoutineKind.rest => AppColors.secondary,
      RoutineKind.cognitive => AppColors.plum,
      RoutineKind.medicine => AppColors.terracotta,
      RoutineKind.social => AppColors.indigo,
    };

String routineLabel(RoutineKind k) => switch (k) {
      RoutineKind.meal => 'Meal',
      RoutineKind.activity => 'Activity',
      RoutineKind.rest => 'Rest',
      RoutineKind.cognitive => 'Thinking',
      RoutineKind.medicine => 'Medicine',
      RoutineKind.social => 'People',
    };

/// Deleting a person or a memory is not undoable, so it is always asked.
Future<bool> confirmDelete(BuildContext context, String what) async {
  final bool? yes = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text('Remove $what?'),
      content: const Text('This cannot be undone.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Keep it'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  return yes ?? false;
}

/// A real photograph if the record has one, the drawing otherwise.
///
/// The fallback is not a nicety: a profile can outlive its files — a backup
/// restored onto a new phone brings the record but not the pictures — and a
/// broken `Image.file` is a grey box with no explanation.
class MemoryPicture extends StatelessWidget {
  const MemoryPicture({
    super.key,
    required this.sceneId,
    required this.photoPath,
    required this.size,
    this.circle = true,
    this.radius,
  });

  final String sceneId;
  final String? photoPath;
  final double size;
  final bool circle;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    if (!PhotoStore.exists(photoPath)) {
      return SceneImage(
        sceneId: sceneId,
        size: size,
        circle: circle,
        radius: radius ?? Corners.md,
      );
    }
    final Widget image = Image.file(
      File(photoPath!),
      width: size,
      height: size,
      fit: BoxFit.cover,
      // The file was there a moment ago and is not now — deleted from under
      // us. Fall back rather than throwing inside a list.
      errorBuilder: (_, __, ___) => SceneImage(
        sceneId: sceneId,
        size: size,
        circle: circle,
        radius: radius ?? Corners.md,
      ),
    );
    return ClipRRect(
      borderRadius:
          circle ? BorderRadius.circular(size) : Corners.r(radius ?? Corners.md),
      child: image,
    );
  }
}

/// "Take a photo / choose one / use a drawing", above the drawing strip.
class PhotoPickerRow extends StatelessWidget {
  const PhotoPickerRow({
    super.key,
    required this.id,
    required this.photoPath,
    required this.onChanged,
  });

  final String id;
  final String? photoPath;

  /// Null clears the photo and falls back to the chosen drawing.
  final ValueChanged<String?> onChanged;

  Future<void> _pick(BuildContext context, {required bool camera}) async {
    final String? path = await PhotoStore.pick(fromCamera: camera, id: id);
    if (path != null) onChanged(path);
  }

  @override
  Widget build(BuildContext context) {
    final bool has = PhotoStore.exists(photoPath);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Photograph', style: AppText.overline),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            if (has) ...<Widget>[
              MemoryPicture(
                sceneId: '',
                photoPath: photoPath,
                size: 64,
                circle: false,
                radius: Corners.md,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: SoftButton(
                          label: has ? 'Replace' : 'Choose',
                          icon: Icons.photo_library_outlined,
                          onPressed: () => _pick(context, camera: false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SoftButton(
                          label: 'Camera',
                          icon: Icons.photo_camera_outlined,
                          onPressed: () => _pick(context, camera: true),
                        ),
                      ),
                    ],
                  ),
                  if (has) ...<Widget>[
                    const SizedBox(height: 6),
                    SoftButton(
                      label: 'Use a drawing instead',
                      icon: Icons.brush_outlined,
                      color: AppColors.inkSoft,
                      onPressed: () => onChanged(null),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
      ],
    );
  }
}

/// A horizontal strip of drawings to pick between.
class ScenePicker extends StatelessWidget {
  const ScenePicker({
    super.key,
    required this.label,
    required this.scenes,
    required this.selected,
    required this.onSelect,
    this.circle = true,
  });

  final String label;
  final List<String> scenes;
  final String selected;
  final ValueChanged<String> onSelect;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppText.overline),
        const SizedBox(height: 8),
        SizedBox(
          height: 74,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: scenes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (BuildContext context, int i) {
              final bool on = scenes[i] == selected;
              return Pressable(
                onTap: () => onSelect(scenes[i]),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: circle ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: circle ? null : Corners.r(Corners.md),
                    border: Border.all(
                      color: on ? AppColors.primary : AppColors.hairline,
                      width: on ? 3 : 1.4,
                    ),
                  ),
                  child: SceneImage(
                    sceneId: scenes[i],
                    size: 60,
                    circle: circle,
                    radius: Corners.sm,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The rounded sheet every editor above sits in.
class SheetShell extends StatelessWidget {
  const SheetShell({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

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
        child: SafeArea(
          top: false,
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
                Text(title, style: AppText.h3, textAlign: TextAlign.center),
                const SizedBox(height: Insets.md),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
