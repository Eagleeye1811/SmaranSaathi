import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/daily.dart';
import '../../../core/models/mood_drawing.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/mock/mock_data.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/clinic_widgets.dart';

/// One Mood Canvas drawing, full size, with a place for the doctor's own
/// freeform note — never generated automatically. No AI reads or scores
/// this drawing; the note is entirely the clinician's own judgement.
class MoodDrawingDetailScreen extends StatefulWidget {
  const MoodDrawingDetailScreen({super.key, required this.drawingId});

  final String drawingId;

  @override
  State<MoodDrawingDetailScreen> createState() => _MoodDrawingDetailScreenState();
}

class _MoodDrawingDetailScreenState extends State<MoodDrawingDetailScreen> {
  late final TextEditingController _note;
  bool _justSaved = false;

  MoodDrawing _drawingOf(AppState state) =>
      state.moodDrawings.firstWhere((MoodDrawing d) => d.id == widget.drawingId);

  @override
  void initState() {
    super.initState();
    final AppState state = AppScope.read(context);
    _note = TextEditingController(text: _drawingOf(state).doctorNote ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save(AppState state) {
    final String text = _note.text.trim();
    if (text.isEmpty) return;
    state.addDoctorNoteToDrawing(widget.drawingId, text, notedBy: MockData.doctorName);
    setState(() => _justSaved = true);
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final MoodDrawing drawing = _drawingOf(state);

    return Theme(
      data: AppTheme.clinic(),
      child: Scaffold(
        backgroundColor: AppColors.clinicBackground,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, 8, Insets.gutter, 10),
                child: Row(
                  children: <Widget>[
                    RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      size: 40,
                      color: AppColors.clinicInk,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l.doctorMoodCanvasDetailTitle, style: CT.h3.wght(800))),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 32),
                  children: <Widget>[
                    ClinicCard(
                      padding: EdgeInsets.zero,
                      child: ClipRRect(
                        borderRadius: Corners.r(Corners.md),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Image.memory(drawing.pngBytes, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    Row(
                      children: <Widget>[
                        Text(drawing.timeLabel, style: CT.caption),
                        if (drawing.moodLevel != null) ...<Widget>[
                          const SizedBox(width: 8),
                          Text('· ${drawing.moodLevel!.emoji} ${drawing.moodLevel!.label}',
                              style: CT.caption.wght(700)),
                        ],
                      ],
                    ),
                    if (drawing.transcript.isNotEmpty) ...<Widget>[
                      const SizedBox(height: Insets.lg),
                      ClinicCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(l.doctorMoodCanvasTranscriptLabel, style: CT.h3),
                            const SizedBox(height: Insets.sm),
                            for (final MoodCheckInTurn t in drawing.transcript) ...<Widget>[
                              Text(t.question, style: CT.bodySmall.wght(700)),
                              const SizedBox(height: 3),
                              Text(t.answer, style: CT.bodySmall),
                              const SizedBox(height: Insets.sm),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: Insets.lg),
                    ClinicCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(l.doctorMoodCanvasNoteLabel, style: CT.h3),
                          const SizedBox(height: Insets.sm),
                          TextField(
                            controller: _note,
                            minLines: 4,
                            maxLines: 8,
                            style: CT.body,
                            decoration: InputDecoration(
                              hintText: l.doctorMoodCanvasNoteHint,
                              border: OutlineInputBorder(borderRadius: Corners.r(Corners.sm)),
                            ),
                            onChanged: (_) {
                              if (_justSaved) setState(() => _justSaved = false);
                            },
                          ),
                          if (drawing.hasNote && drawing.notedBy != null) ...<Widget>[
                            const SizedBox(height: Insets.sm),
                            Text(
                              l.doctorMoodCanvasNotedByline(
                                  drawing.notedBy!, drawing.notedAtIso ?? ''),
                              style: CT.caption,
                            ),
                          ],
                          const SizedBox(height: Insets.md),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _note,
                            builder: (BuildContext context, TextEditingValue value, _) {
                              return BigButton(
                                label:
                                    _justSaved ? l.doctorMoodCanvasNoteSaved : l.doctorMoodCanvasSaveNote,
                                icon: Icons.check_rounded,
                                color: AppColors.clinicAccent,
                                onPressed: value.text.trim().isEmpty ? null : () => _save(state),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
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
