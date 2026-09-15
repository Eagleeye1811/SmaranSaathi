import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text.dart';
import '../../../../core/services/app_state.dart';
import '../models/learning_models.dart';

/// Interactive AI Consultation portal personalized to the caregiver's specific patient.
class PersonalizedQASectionWidget extends StatefulWidget {
  const PersonalizedQASectionWidget({
    super.key,
    required this.state,
  });

  final AppState state;

  @override
  State<PersonalizedQASectionWidget> createState() => _PersonalizedQASectionWidgetState();
}

class _PersonalizedQASectionWidgetState extends State<PersonalizedQASectionWidget> {
  final TextEditingController _questionController = TextEditingController();
  bool _isLoading = false;

  final List<PersonalizedQAQuery> _history = <PersonalizedQAQuery>[];

  final List<String> _quickPrompts = <String>[
    'My patient gets agitated and asks to go home around sunset',
    'How should I handle food refusal during dinner?',
    'What should I do if medication is refused?',
    'How to prevent nighttime wandering and fall risks?',
  ];

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  String _generateClinicalResponse(String query, String patientName) {
    final String q = query.toLowerCase();

    if (q.contains('home') ||
        q.contains('sunset') ||
        q.contains('agitat') ||
        q.contains('sundown') ||
        q.contains('restless')) {
      return 'Clinical Advice for $patientName:\n\nThis behavior is a classic sign of "Sundowning" in Stage 2 cognitive decline. The request to "go home" or late-afternoon restlessness is an emotional desire for security, warmth, and safety.\n\nRecommended Actions:\n• Validate, Don’t Correct: Say: "$patientName, you are completely safe here with me. Tell me about your favorite memories of home."\n• Lighting & Environment: Turn on warm indoor lights by 4:30 PM to eliminate evening shadows.\n• Sensory Calm: Play soft familiar music and offer a warm cup of herbal tea.\n• Distraction: Gently shift attention to folding towels or browsing a photo album.';
    } else if (q.contains('eat') ||
        q.contains('food') ||
        q.contains('dinner') ||
        q.contains('appetite') ||
        q.contains('refus')) {
      return 'Clinical Advice for $patientName:\n\nEating difficulty or food refusal can stem from sensory fatigue, difficulty using utensils, or swallowed memory prompts.\n\nRecommended Actions:\n• Finger Foods & Small Portions: Serve easy-to-pick foods (cut fruits, small rolls, soft snacks).\n• High Visual Contrast: Use dark-colored plates against light tablecloths so food stands out clearly.\n• Eat Together: Sit across from $patientName and take bites first to trigger mirror behavior.\n• Avoid Rushing: Allow 45 minutes without noise or television distractions.';
    } else if (q.contains('medic') ||
        q.contains('pill') ||
        q.contains('forget') ||
        q.contains('dose')) {
      return 'Clinical Advice for $patientName:\n\nForgetting or refusing medication is common in Stage 2 dementia due to swallowing fear or paranoia.\n\nRecommended Actions:\n• Pair with Enjoyable Habit: Offer medicine with a cup of warm tea or a favorite spoon of jam.\n• Stay Calm & Reassure: Say "$patientName, doctor prescribed this to help your joints feel better today."\n• Check Alternatives: Ask their doctor if liquid or chewable formats are available.\n• Never Force: If refused, wait 20 minutes and try again in a relaxed mood.';
    } else if (q.contains('wander') ||
        q.contains('walk') ||
        q.contains('night') ||
        q.contains('door')) {
      return 'Clinical Advice for $patientName:\n\nNighttime wandering usually indicates restlessness, need to use the bathroom, or disorientation.\n\nRecommended Actions:\n• Motion Nightlights: Install automatic nightlights along hallway to the bathroom.\n• Door Chimes: Place subtle chimes on exit doors to alert you immediately.\n• Daytime Activity: Ensure $patientName engages in light morning physical walks and cognitive games.\n• Clear Walking Paths: Keep corridors free of electrical cords and rugs.';
    } else {
      return 'Clinical Advice for $patientName:\n\nRegarding your query: "$query"\n\nBased on $patientName\'s current Stage 2 cognitive profile and daily history, the best clinical practice is calm reassurance and non-confrontational communication.\n\nKey Principles:\n• Validate Emotional State: Acknowledge how $patientName feels before addressing the situation.\n• Simplify Directives: Give clear, single-step prompts with warm visual cues.\n• Consistent Routine: Keep daily sleep, meal, and memory game times predictable.\n• Monitor Symptoms: Log any sudden behavioral shifts in SmaranSaathi for doctor review.';
    }
  }

  List<String> _generateSuggestedActions(String query) {
    final String q = query.toLowerCase();
    if (q.contains('home') || q.contains('sunset') || q.contains('agitat') || q.contains('sundown')) {
      return const <String>[
        'Turn on warm indoor lights by 4:30 PM',
        'Validate feelings: "You are safe with me"',
        'Play soft familiar music & offer warm tea',
        'Redirect to folding towels or photo albums',
      ];
    } else if (q.contains('eat') || q.contains('food') || q.contains('dinner')) {
      return const <String>[
        'Serve finger foods on high-contrast plates',
        'Eat together to encourage mirror eating',
        'Ensure quiet, distraction-free environment',
      ];
    } else if (q.contains('medic') || q.contains('pill')) {
      return const <String>[
        'Pair pills with warm tea or jam',
        'Ask doctor about liquid alternatives',
        'Wait 20 mins if refused; never force',
      ];
    } else {
      return const <String>[
        'Log response in Daily Memory Notes',
        'Maintain predictable daily routine',
        'Consult doctor if symptoms persist',
      ];
    }
  }

  void _submitQuestion(String query) {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final String patientName = widget.state.patient.name.isNotEmpty
          ? widget.state.patient.name
          : 'your patient';

      final String responseText = _generateClinicalResponse(query, patientName);
      final List<String> actions = _generateSuggestedActions(query);

      setState(() {
        _history.insert(
          0,
          PersonalizedQAQuery(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            question: query,
            answer: responseText,
            timestamp: DateTime.now(),
            patientName: patientName,
            suggestedActions: actions,
          ),
        );
        _isLoading = false;
        _questionController.clear();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final String patientName = widget.state.patient.name.isNotEmpty
        ? widget.state.patient.name
        : 'Your Patient';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ── Patient Context Banner ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                AppColors.primary.withValues(alpha: 0.12),
                AppColors.accent.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: AppColors.primary,
                radius: 22,
                child: Text(
                  patientName[0].toUpperCase(),
                  style: AppText.h3.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            'Personalized for $patientName',
                            style: AppText.body.wght(700).copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, size: 16, color: AppColors.primary),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'AI Consultation context active • Stage 2 Cognitive Profile',
                      style: AppText.caption.copyWith(color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ── Question Input Card ───────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.hairline),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Ask a question specific to $patientName:',
                style: AppText.body.wght(700).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _questionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'e.g. How do I help $patientName when they refuse to drink water in the afternoon?',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.hairline),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Quick Prompts Chips
              Text(
                'Quick Prompts:',
                style: AppText.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickPrompts.map((String prompt) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(prompt, style: const TextStyle(fontSize: 12)),
                        onPressed: () {
                          _questionController.text = prompt;
                        },
                        backgroundColor: AppColors.primary.withValues(alpha: 0.07),
                        side: BorderSide.none,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      _isLoading ? null : () => _submitQuestion(_questionController.text),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.psychology_rounded, size: 18),
                  label: Text(_isLoading ? 'Analyzing Patient Context...' : 'Get AI Advice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // ── History of Consultation Q&As ──────────────────────────────
        Text(
          'Personalized Consultation History',
          style: AppText.h3.copyWith(fontSize: 17),
        ),
        const SizedBox(height: 12),

        if (_history.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              children: <Widget>[
                const Icon(Icons.chat_bubble_outline_rounded, size: 36, color: AppColors.primarySoft),
                const SizedBox(height: 10),
                Text(
                  'No consultation asked yet.',
                  style: AppText.body.wght(700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Type a question above or tap any quick prompt to receive instant personalized clinical advice for $patientName.',
                  style: AppText.caption.copyWith(color: AppColors.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _history.length,
          itemBuilder: (BuildContext context, int index) {
            final PersonalizedQAQuery item = _history[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.hairline),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Question Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.help_center_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.question,
                          style: AppText.body.wght(700).copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // AI Clinical Answer
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.auto_awesome_rounded, color: AppColors.secondary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.answer,
                          style: AppText.body.copyWith(height: 1.5),
                        ),
                      ),
                    ],
                  ),

                  // Suggested Actions
                  if (item.suggestedActions.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Recommended Next Steps:',
                            style: AppText.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...item.suggestedActions.map(
                            (String action) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                children: <Widget>[
                                  const Icon(Icons.arrow_right_rounded,
                                      size: 16, color: AppColors.secondary),
                                  Expanded(
                                    child: Text(action, style: AppText.bodySmall),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
