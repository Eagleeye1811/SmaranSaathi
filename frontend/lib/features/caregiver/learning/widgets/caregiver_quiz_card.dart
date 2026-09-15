import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text.dart';
import '../data/learning_repository.dart';
import '../models/learning_models.dart';

/// Caregiver Stress Check-in & Counselling Assessment widget.
class CaregiverQuizCardWidget extends StatefulWidget {
  const CaregiverQuizCardWidget({super.key});

  @override
  State<CaregiverQuizCardWidget> createState() => _CaregiverQuizCardWidgetState();
}

class _CaregiverQuizCardWidgetState extends State<CaregiverQuizCardWidget> {
  final Map<int, int> _selectedAnswers = <int, int>{};
  StressLevelResult? _result;

  void _calculateScore() {
    final int total = _selectedAnswers.values.fold(0, (int a, int b) => a + b);
    setState(() {
      _result = LearningRepository.evaluateStressScore(total);
    });
  }

  void _resetQuiz() {
    setState(() {
      _selectedAnswers.clear();
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<CaregiverQuizQuestion> questions = LearningRepository.stressQuizQuestions;
    final bool allAnswered = _selectedAnswers.length == questions.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
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
          // Header
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Caregiver Stress Check-in',
                      style: AppText.h3.copyWith(fontSize: 17),
                    ),
                    Text(
                      '4 quick questions for psychological counseling & guidance',
                      style: AppText.caption.copyWith(color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          if (_result != null) ...<Widget>[
            // ── Result & Counseling View ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _result!.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _result!.color.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.health_and_safety_rounded, color: _result!.color, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        _result!.title,
                        style: AppText.h3.copyWith(color: _result!.color, fontSize: 17),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _result!.description,
                    style: AppText.body.copyWith(height: 1.4, color: AppColors.ink),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Recommended Counseling Actions:',
                    style: AppText.body.wght(700).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._result!.counselingTips.map(
                    (String tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(Icons.check_circle_rounded, size: 16, color: _result!.color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(tip, style: AppText.bodySmall),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _resetQuiz,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retake Stress Check-in'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ] else ...<Widget>[
            // ── Questions View ─────────────────────────────────────────
            for (int i = 0; i < questions.length; i++) ...<Widget>[
              Text(
                '${i + 1}. ${questions[i].questionText}',
                style: AppText.body.wght(700).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Column(
                children: questions[i].options.map((CaregiverQuizOption opt) {
                  final bool isSelected = _selectedAnswers[i] == opt.score;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () => setState(() => _selectedAnswers[i] = opt.score),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.hairline,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              size: 18,
                              color: isSelected ? AppColors.primary : AppColors.inkMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                opt.text,
                                style: AppText.bodySmall.copyWith(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? AppColors.primary : AppColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: allAnswered ? _calculateScore : null,
                icon: const Icon(Icons.assessment_rounded, size: 18),
                label: const Text('Evaluate My Stress Level'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
