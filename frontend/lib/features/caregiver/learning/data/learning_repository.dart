import 'package:flutter/material.dart';
import '../models/learning_models.dart';

/// Repository providing educational content, video tutorials, FAQs, and counseling datasets.
class LearningRepository {
  const LearningRepository._();

  /// Curated photo-based visual step-by-step guides.
  static List<VisualGuide> get visualGuides => const <VisualGuide>[
        VisualGuide(
          id: 'vg_hygiene',
          title: 'Assisting with Daily Hygiene & Bathing',
          subtitle: 'A dignified, calm step-by-step approach to daily bathing without anxiety.',
          category: LearningCategory.dailyCareAndHygiene,
          estimatedMinutes: 5,
          badgeText: '5 Photo Steps',
          steps: <PhotoGuideStep>[
            PhotoGuideStep(
              stepNumber: 1,
              title: 'Prepare Room & Warmth First',
              description:
                  'Ensure the bathroom is warm, well-lit, and non-slip mats are secured before bringing the patient in. Keep towels and clothing ready within arm reach.',
              icon: Icons.thermostat_rounded,
              proTip: 'Dementia patients often fear sudden cold or water spray noise. Keep water temperature mild.',
            ),
            PhotoGuideStep(
              stepNumber: 2,
              title: 'Use Clear, Gentle 1-Step Instructions',
              description:
                  'Avoid complex sentences like "Get unbuttoned and get in". Instead say, "Let us sit here comfortably first". Speak in a reassuring, slow tone.',
              icon: Icons.record_voice_over_rounded,
              proTip: 'Maintain eye contact and smile to eliminate feeling rushed.',
            ),
            PhotoGuideStep(
              stepNumber: 3,
              title: 'Preserve Independence Where Possible',
              description:
                  'Hand them the washcloth with soap already on it. Prompt them to wash their hands or face first so they feel in control.',
              icon: Icons.clean_hands_rounded,
              proTip: 'Active involvement reduces anxiety and resistance.',
            ),
            PhotoGuideStep(
              stepNumber: 4,
              title: 'Keep Body Covered for Modesty',
              description:
                  'Cover parts of the body not being washed with a warm towel. This prevents shivering and respects personal modesty.',
              icon: Icons.dry_cleaning_rounded,
            ),
            PhotoGuideStep(
              stepNumber: 5,
              title: 'Pat Dry Thoroughly & Apply Barrier Lotion',
              description:
                  'Pat skin dry gently (do not rub skin folds). Apply moisturizing lotion to prevent dryness and skin breakdown.',
              icon: Icons.spa_rounded,
              proTip: 'Inspect skin for any red spots, pressure marks, or rashes during drying.',
            ),
          ],
        ),
        VisualGuide(
          id: 'vg_sundowning',
          title: 'De-escalating Night Agitation (Sundowning)',
          subtitle: 'Visual techniques to soothe late-afternoon restlessness and confusion.',
          category: LearningCategory.behaviorManagement,
          estimatedMinutes: 6,
          badgeText: '4 Photo Steps',
          steps: <PhotoGuideStep>[
            PhotoGuideStep(
              stepNumber: 1,
              title: 'Close Blinds & Turn on Warm Lights Early',
              description:
                  'As daylight fades around 4–5 PM, turn on interior lights to remove shadows that cause visual hallucinations or confusion.',
              icon: Icons.light_mode_rounded,
              proTip: 'Shadows in corners often trigger anxiety in middle-stage dementia.',
            ),
            PhotoGuideStep(
              stepNumber: 2,
              title: 'Introduce Familiar Soothing Sounds',
              description:
                  'Play gentle soft instrumental music, devotional chants, or familiar old songs they enjoyed in their youth.',
              icon: Icons.music_note_rounded,
              proTip: 'Rhythmic, familiar tunes activate long-term emotional memory centers.',
            ),
            PhotoGuideStep(
              stepNumber: 3,
              title: 'Validate Feelings Instead of Correcting',
              description:
                  'If they say "I need to go home to my parents", do not say "You are 80 years old". Instead say, "Tell me about your childhood home while we sip warm tea".',
              icon: Icons.favorite_border_rounded,
              proTip: 'Validation calms the nervous system; harsh logic escalates agitation.',
            ),
            PhotoGuideStep(
              stepNumber: 4,
              title: 'Engage in Simple Calming Tactile Tasks',
              description:
                  'Give them a soft blanket to fold, a photo album to hold, or light hand massage with lavender oil.',
              icon: Icons.back_hand_rounded,
            ),
          ],
        ),
        VisualGuide(
          id: 'vg_safety',
          title: 'Creating a Safe Home Environment',
          subtitle: 'Simple room-by-room modifications to prevent falls and wandering.',
          category: LearningCategory.homeSafety,
          estimatedMinutes: 4,
          badgeText: '4 Photo Steps',
          steps: <PhotoGuideStep>[
            PhotoGuideStep(
              stepNumber: 1,
              title: 'Remove Throw Rugs & Clutter',
              description:
                  'Clear electrical cords, loose rugs, and low coffee tables from primary walking paths to prevent tripping.',
              icon: Icons.do_not_disturb_on_rounded,
            ),
            PhotoGuideStep(
              stepNumber: 2,
              title: 'Install Contrast Colors on Steps & Doors',
              description:
                  'Apply high-contrast tape on stair edges and bathroom doorframes so diminished depth perception does not cause missteps.',
              icon: Icons.auto_awesome_mosaic_rounded,
            ),
            PhotoGuideStep(
              stepNumber: 3,
              title: 'Secure Medicines & Cleaning Chemicals',
              description:
                  'Lock away all prescription drugs, cleaning fluids, and sharp utensils in child-proof cabinets.',
              icon: Icons.lock_clock_rounded,
            ),
            PhotoGuideStep(
              stepNumber: 4,
              title: 'Set Up Safe Zone & Motion Nightlights',
              description:
                  'Install motion-activated nightlights along hallway corridors to guide midnight bathroom trips safely.',
              icon: Icons.nights_stay_rounded,
            ),
          ],
        ),
        VisualGuide(
          id: 'vg_comm',
          title: 'Effective Dementia Communication',
          subtitle: 'How to talk so your loved one feels respected, understood, and calm.',
          category: LearningCategory.communication,
          estimatedMinutes: 5,
          badgeText: '5 Photo Steps',
          steps: <PhotoGuideStep>[
            PhotoGuideStep(
              stepNumber: 1,
              title: 'Get Down to Eye Level',
              description:
                  'Always approach from the front, sit or kneel down to their eye level, and state your name clearly.',
              icon: Icons.visibility_rounded,
            ),
            PhotoGuideStep(
              stepNumber: 2,
              title: 'Ask One Question at a Time',
              description:
                  'Offer simple choices with visual cues: "Would you like tea or milk?" while pointing to the cups.',
              icon: Icons.help_outline_rounded,
            ),
            PhotoGuideStep(
              stepNumber: 3,
              title: 'Give 10 Seconds for Processing',
              description:
                  'Brain processing slows down with cognitive decline. Wait patiently without interrupting or repeating too quickly.',
              icon: Icons.timer_rounded,
            ),
            PhotoGuideStep(
              stepNumber: 4,
              title: 'Use Reassuring Touch & Body Language',
              description:
                  'Place your hand gently on theirs or hold their arm softly to convey safety and warmth.',
              icon: Icons.touch_app_rounded,
            ),
            PhotoGuideStep(
              stepNumber: 5,
              title: 'Never Argue or Scold',
              description:
                  'Focus on the emotional content behind their words rather than factual accuracy.',
              icon: Icons.sentiment_very_satisfied_rounded,
            ),
          ],
        ),
      ];

  /// Curated video tutorial sessions for caregivers.
  static List<VideoTutorial> get videoTutorials => const <VideoTutorial>[
        VideoTutorial(
          id: 'vt_youtube_dementia',
          title: 'Understanding Dementia & Patient Counseling',
          description:
              'Essential clinical guide and practical counseling for family caregivers managing dementia and memory loss.',
          category: LearningCategory.dementiaBasics,
          durationMinutes: 15,
          instructorName: 'Dr. Ananya Sharma',
          instructorRole: 'Geriatric Specialist',
          videoUrl: 'https://youtu.be/hahvUXwTXE4?si=mn82fMtd6FYaeg6R',
          thumbnailUrl: 'https://img.youtube.com/vi/hahvUXwTXE4/hqdefault.jpg',
        ),
        VideoTutorial(
          id: 'vt_transfers',
          title: 'Safe Physical Assistance & Ergonomics',
          description:
              'Learn physical transfer techniques to guide your loved one from bed to chair without hurting your back or scaring them.',
          category: LearningCategory.dailyCareAndHygiene,
          durationMinutes: 8,
          instructorName: 'Rajesh Verma',
          instructorRole: 'Senior Physiotherapist',
          videoUrl: 'assets/videos/washing_clothes.mp4',
          thumbnailUrl: 'https://images.unsplash.com/photo-1576765608535-5f04d1e3f289?w=600&auto=format&fit=crop&q=80',
        ),
        VideoTutorial(
          id: 'vt_burnout',
          title: 'Overcoming Caregiver Guilt & Exhaustion',
          description:
              'Practical psychological counseling session on managing emotional burnout, setting boundaries, and taking respite time guilt-free.',
          category: LearningCategory.selfCareAndBurnout,
          durationMinutes: 10,
          instructorName: 'Dr. Meera Nambiar',
          instructorRole: 'Clinical Psychologist',
          videoUrl: 'assets/videos/procedural_test.mp4',
          thumbnailUrl: 'https://images.unsplash.com/photo-1544027993-37dbfe43562a?w=600&auto=format&fit=crop&q=80',
        ),
        VideoTutorial(
          id: 'vt_nutrition',
          title: 'Managing Eating Difficulties & Swallowing Safety',
          description:
              'Strategies for patients who forget to eat, refuse food, or experience mild swallowing difficulties.',
          category: LearningCategory.dailyCareAndHygiene,
          durationMinutes: 9,
          instructorName: 'Sunita Menon',
          instructorRole: 'Clinical Nutritionist',
          videoUrl: 'assets/videos/washing_clothes.mp4',
          thumbnailUrl: 'https://images.unsplash.com/photo-1498837167922-ddd27525d352?w=600&auto=format&fit=crop&q=80',
        ),
      ];

  /// Categorized FAQ knowledge base.
  static List<FaqItem> get faqs => const <FaqItem>[
        FaqItem(
          id: 'faq_1',
          question: 'What should I do if my loved one refuses to take their medication?',
          answer:
              'Medication refusal is very common. First, stay calm and do not force or scold. Try offering the medicine at a different time when they are relaxed. Check if pills are difficult to swallow (consult your doctor if liquid or crushed alternatives are safe). Pair medicine time with a pleasant habit like a cup of warm tea or a favorite treat.',
          category: LearningCategory.dailyCareAndHygiene,
          keyTakeaways: <String>[
            'Never force or argue during refusal',
            'Consult doctor for liquid/crushed options',
            'Pair with a comforting routine like tea time',
          ],
        ),
        FaqItem(
          id: 'faq_2',
          question: 'How do I respond when they ask to "go home" even though they are at home?',
          answer:
              '"I want to go home" usually signifies a desire for security, warmth, and familiarity rather than a physical location. Validate their emotion by saying, "You are safe with me. Tell me about your favorite room in your home." After listening for 2–3 minutes, gently redirect their attention to an activity like folding towels or drinking juice.',
          category: LearningCategory.behaviorManagement,
          keyTakeaways: <String>[
            'Validate the feeling of wanting safety',
            'Avoid insisting "You are already home"',
            'Redirect gently to a soothing activity',
          ],
        ),
        FaqItem(
          id: 'faq_3',
          question: 'How can I manage caregiver burnout and constant stress?',
          answer:
              'Caregiver burnout is real and dangerous for both you and your patient. Schedule non-negotiable 15-minute daily breaks for yourself. Reach out to family members or professional respite aides to share duties. Remind yourself: taking care of yourself is not selfish—it is necessary to be a good caregiver.',
          category: LearningCategory.selfCareAndBurnout,
          keyTakeaways: <String>[
            'Take 15-minute daily quiet breaks',
            'Accept help from family & community',
            'Self-care is essential caregiving',
          ],
        ),
        FaqItem(
          id: 'faq_4',
          question: 'What steps should I take if they wander outside the safe zone?',
          answer:
              'Ensure SmaranSaathi Geofence alerts are active on your phone. Keep recent photographs of your patient and a list of their favorite places updated. Place subtle door chimes or motion sensors on exterior exit doors. Keep ID cards or wearable GPS tags in their pocket/wristband.',
          category: LearningCategory.homeSafety,
          keyTakeaways: <String>[
            'Enable GPS Safe Zone alerts',
            'Use door chimes or motion detectors',
            'Ensure wearable ID with contact numbers',
          ],
        ),
        FaqItem(
          id: 'faq_5',
          question: 'How do I know when it is time to consult a neurologist or doctor?',
          answer:
              'Schedule a medical review if you notice sudden changes in behavior, sharp decline in memory over days, new physical weakness, sudden sleep disruption, or signs of pain/infection (UTIs frequently cause acute delirium in dementia patients).',
          category: LearningCategory.dementiaBasics,
          keyTakeaways: <String>[
            'Sudden acute changes need medical review',
            'Rule out UTIs & physical infections',
            'Keep a log of symptoms in SmaranSaathi',
          ],
        ),
        FaqItem(
          id: 'faq_6',
          question: 'What legal and financial documents should be organized early?',
          answer:
              'Organize Power of Attorney (POA) for healthcare and financial decisions while your loved one can still participate in legal consent. Keep medical insurance policies, bank account details, property deeds, and advance care directives in a secure, accessible folder.',
          category: LearningCategory.legalAndFinancial,
          keyTakeaways: <String>[
            'Establish Power of Attorney early',
            'Keep medical & financial records central',
            'Discuss care preferences while possible',
          ],
        ),
      ];

  /// Caregiver Stress Check-in Questions.
  static List<CaregiverQuizQuestion> get stressQuizQuestions => const <CaregiverQuizQuestion>[
        CaregiverQuizQuestion(
          id: 'q1',
          questionText: 'How often do you feel overwhelmed or exhausted by your caregiving duties?',
          options: <CaregiverQuizOption>[
            CaregiverQuizOption(text: 'Rarely or Never', score: 0),
            CaregiverQuizOption(text: 'Sometimes (1-2 days/week)', score: 1),
            CaregiverQuizOption(text: 'Frequently (3-5 days/week)', score: 2),
            CaregiverQuizOption(text: 'Almost Every Day', score: 3),
          ],
        ),
        CaregiverQuizQuestion(
          id: 'q2',
          questionText: 'Do you feel you have enough personal time for rest, hobbies, or friends?',
          options: <CaregiverQuizOption>[
            CaregiverQuizOption(text: 'Yes, I balance it well', score: 0),
            CaregiverQuizOption(text: 'I get some time occasionally', score: 1),
            CaregiverQuizOption(text: 'Very little personal time', score: 2),
            CaregiverQuizOption(text: 'No time at all for myself', score: 3),
          ],
        ),
        CaregiverQuizQuestion(
          id: 'q3',
          questionText: 'How often do you feel anxious, irritable, or tearful about your loved one’s illness?',
          options: <CaregiverQuizOption>[
            CaregiverQuizOption(text: 'Rarely', score: 0),
            CaregiverQuizOption(text: 'Occasionally', score: 1),
            CaregiverQuizOption(text: 'Quite Often', score: 2),
            CaregiverQuizOption(text: 'Constantly', score: 3),
          ],
        ),
        CaregiverQuizQuestion(
          id: 'q4',
          questionText: 'Do you feel supported by family members or external healthcare resources?',
          options: <CaregiverQuizOption>[
            CaregiverQuizOption(text: 'Very well supported', score: 0),
            CaregiverQuizOption(text: 'Moderately supported', score: 1),
            CaregiverQuizOption(text: 'Slightly supported', score: 2),
            CaregiverQuizOption(text: 'I feel completely alone in this', score: 3),
          ],
        ),
      ];

  /// Computes counseling advice based on caregiver stress score.
  static StressLevelResult evaluateStressScore(int totalScore) {
    if (totalScore <= 3) {
      return const StressLevelResult(
        title: 'Healthy Caregiver Balance',
        level: 'Low Stress',
        color: Colors.green,
        description:
            'You are maintaining a healthy balance in your caregiving journey. Keep honoring your personal boundaries and rest time.',
        counselingTips: <String>[
          'Continue taking your regular short breaks daily.',
          'Keep engaging in your hobbies and social interactions.',
          'Review caregiver educational guides to prepare for future stages.',
        ],
      );
    } else if (totalScore <= 7) {
      return const StressLevelResult(
        title: 'Mild to Moderate Caregiver Fatigue',
        level: 'Moderate Stress',
        color: Colors.orange,
        description:
            'You are experiencing noticeable emotional or physical tiredness. Taking proactive steps now will prevent deeper burnout.',
        counselingTips: <String>[
          'Delegate 1–2 daily tasks to another family member or neighbor.',
          'Try 10 minutes of guided deep breathing or calming music each evening.',
          'Watch our Caregiver Burnout video tutorial in the Visual Learning tab.',
        ],
      );
    } else {
      return const StressLevelResult(
        title: 'Significant Caregiver Burnout Warning',
        level: 'High Stress',
        color: Colors.redAccent,
        description:
            'Your stress and exhaustion levels are high. It is vital for your health and your patient’s safety that you seek support today.',
        counselingTips: <String>[
          'Schedule an urgent respite care break or family meeting to share care duties.',
          'Speak with your doctor or a clinical counselor regarding caregiver support.',
          'Utilize SmaranSaathi AI Patient Consultation to streamline daily care decisions.',
        ],
      );
    }
  }

  /// Practical Caregiver Checklists.
  static List<CaregiverChecklist> get checklists => <CaregiverChecklist>[
        CaregiverChecklist(
          id: 'chk_home_safety',
          title: 'Home Fall & Wandering Audit',
          description: 'Essential room safety items to inspect regularly.',
          category: LearningCategory.homeSafety,
          items: <ChecklistItem>[
            ChecklistItem(
                title: 'High-contrast tape on stairs', subtitle: 'Improves depth perception'),
            ChecklistItem(
                title: 'Non-slip rubber bath mats', subtitle: 'Secured inside shower & floor'),
            ChecklistItem(
                title: 'Clear hallway walking paths', subtitle: 'Removed loose rug edges & cords'),
            ChecklistItem(
                title: 'Nightlights in bathroom path', subtitle: 'Automatic motion sensors'),
            ChecklistItem(
                title: 'Medicines & cleaning chemicals locked', subtitle: 'In secure cabinet'),
          ],
        ),
        CaregiverChecklist(
          id: 'chk_doctor_visit',
          title: 'Doctor Visit Preparation Checklist',
          description: 'What to record before taking your patient to their appointment.',
          category: LearningCategory.dementiaBasics,
          items: <ChecklistItem>[
            ChecklistItem(
                title: 'List of current medications & doses', subtitle: 'Include supplements'),
            ChecklistItem(
                title: 'Log of recent behavioral changes', subtitle: 'Agitation, sleep, memory'),
            ChecklistItem(
                title: 'SmaranSaathi cognitive game scores', subtitle: 'Export or show screen'),
            ChecklistItem(
                title: 'Questions for doctor written down', subtitle: 'Side effects, care tips'),
          ],
        ),
      ];
}
