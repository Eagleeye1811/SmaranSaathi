import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memory_mitra/app/theme/app_theme.dart';
import 'package:memory_mitra/core/services/app_state.dart';
import 'package:memory_mitra/features/caregiver/caregiver_shell.dart';
import 'package:memory_mitra/features/caregiver/onboarding/patient_onboarding_flow.dart';
import 'package:memory_mitra/features/doctor/doctor_shell.dart';
import 'package:memory_mitra/features/doctor/patients/patient_detail_screen.dart';
import 'package:memory_mitra/features/patient/games/familiar_place/familiar_place_game.dart';
import 'package:memory_mitra/features/patient/games/melody/melody_game.dart';
import 'package:memory_mitra/features/patient/games/memory_cards/memory_cards_game.dart';
import 'package:memory_mitra/features/patient/games/procedure/procedure_game.dart';
import 'package:memory_mitra/features/patient/games/story/story_game.dart';
import 'package:memory_mitra/features/patient/games/weaves/weaves_game.dart';
import 'package:memory_mitra/features/patient/memories/memory_wallet_screen.dart';
import 'package:memory_mitra/features/patient/patient_shell.dart';

/// Layout regression suite.
///
/// `flutter_test` turns any RenderFlex overflow into a test failure, so
/// walking every screen at several device sizes is the cheapest way to keep
/// the prototype presentable on whatever handset a judge picks up.

const Size kPhoneSmall = Size(360, 690); // budget Android
const Size kPhone = Size(393, 852); // iPhone 17
const Size kPhoneLarge = Size(430, 932); // large Android
const Size kTablet = Size(834, 1112); // portrait tablet
const Size kTabletLandscape = Size(1112, 834);

extension _Sizing on WidgetTester {
  void setSurface(Size size) {
    view.physicalSize = size * 3;
    view.devicePixelRatio = 3;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  }
}

Widget harness(Widget child, {AppState? state}) {
  return AppScope(
    state: state ?? AppState(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.warm(),
      home: child,
    ),
  );
}

/// Pump without settling — the companion animates forever.
Future<void> beat(WidgetTester tester, [int ms = 500]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

/// Taps a chip in a horizontal chip row, scrolling it into view first.
/// Chips scrolled far off-screen are unmounted, so we rewind to the start
/// before looking.
Future<void> tapChip(WidgetTester tester, Finder row, String label) async {
  Finder chip() => find.descendant(of: row, matching: find.text(label));
  if (chip().evaluate().isEmpty) {
    await tester.drag(row, const Offset(700, 0));
    await beat(tester);
  }
  if (chip().evaluate().isEmpty) {
    await tester.dragUntilVisible(chip(), row, const Offset(-140, 0));
    await beat(tester);
  }
  expect(chip(), findsOneWidget, reason: 'chip "$label" is missing');
  await tester.ensureVisible(chip());
  await beat(tester);
  await tester.tap(chip());
  await beat(tester);
}

void main() {
  group('patient shell renders on every size', () {
    for (final (String name, Size size) in <(String, Size)>[
      ('small phone', kPhoneSmall),
      ('phone', kPhone),
      ('large phone', kPhoneLarge),
      ('tablet', kTablet),
    ]) {
      testWidgets('all five tabs · $name', (WidgetTester tester) async {
        tester.setSurface(size);
        final AppState state = AppState()..setRole(AppRole.patient);
        await tester.pumpWidget(harness(const PatientShell(), state: state));
        await beat(tester);

        for (final String tab in <String>[
          'Activities',
          'Progress',
          'Companion',
          'Profile',
          'Home',
        ]) {
          await tester.tap(find.text(tab).last);
          await beat(tester);
          expect(tester.takeException(), isNull, reason: '$tab overflowed on $name');
        }
      });
    }
  });

  group('memory wallet tabs', () {
    testWidgets('every category renders', (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.patient);
      // The wallet moved off the navigation bar and onto the dashboard, so the
      // screen is exercised directly rather than through a tab.
      await tester.pumpWidget(harness(const MemoryWalletScreen(), state: state));
      await beat(tester);

      final Finder chips = find.byKey(const Key('wallet-tabs'));
      for (final String tab in <String>[
        'My Places',
        'My Stories',
        'My Favourites',
        'My Memories',
        'My Family',
      ]) {
        await tapChip(tester, chips, tab);
        expect(tester.takeException(), isNull, reason: '$tab overflowed');
      }
    });
  });

  group('caregiver shell', () {
    for (final (String name, Size size) in <(String, Size)>[
      ('small phone', kPhoneSmall),
      ('phone', kPhone),
      ('tablet', kTablet),
    ]) {
      testWidgets('all five tabs · $name', (WidgetTester tester) async {
        tester.setSurface(size);
        final AppState state = AppState()..setRole(AppRole.caregiver);
        await tester.pumpWidget(harness(const CaregiverShell(), state: state));
        await beat(tester);

        for (final String tab in <String>[
          'Patient',
          'Activity',
          'Reminders',
          'Profile',
          'Dashboard',
        ]) {
          await tester.tap(find.text(tab).last);
          await beat(tester, 1200);
          expect(tester.takeException(), isNull, reason: '$tab overflowed on $name');
        }
      });
    }

    testWidgets('memory profile sub-tabs render', (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.caregiver);
      await tester.pumpWidget(harness(const CaregiverShell(), state: state));
      await beat(tester);
      await tester.tap(find.text('Patient').last);
      await beat(tester);

      final Finder chips = find.byKey(const Key('profile-tabs'));
      for (final String tab in <String>['Memories', 'Photographs', 'Routine', 'People']) {
        await tapChip(tester, chips, tab);
        expect(tester.takeException(), isNull, reason: '$tab overflowed');
      }
    });
  });

  group('doctor shell', () {
    for (final (String name, Size size) in <(String, Size)>[
      ('small phone', kPhoneSmall),
      ('phone', kPhone),
      ('tablet', kTablet),
    ]) {
      testWidgets('all five tabs · $name', (WidgetTester tester) async {
        tester.setSurface(size);
        final AppState state = AppState()..setRole(AppRole.doctor);
        await tester.pumpWidget(harness(const DoctorShell(), state: state));
        await beat(tester, 1200);

        for (final String tab in <String>[
          'Patients',
          'Analytics',
          'Alerts',
          'Profile',
          'Overview',
        ]) {
          await tester.tap(find.text(tab).last);
          await beat(tester, 1200);
          expect(tester.takeException(), isNull, reason: '$tab overflowed on $name');
        }
      });
    }

    testWidgets('patient record renders', (WidgetTester tester) async {
      tester.setSurface(kPhone);
      await tester.pumpWidget(
        harness(const PatientDetailScreen(patientId: 'p_aama')),
      );
      await beat(tester, 1200);
      expect(find.text('Patient record'), findsOneWidget);
      expect(find.text('Cognitive profile'), findsOneWidget);

      // Scroll the whole record to force every card through layout.
      await tester.drag(find.byType(ListView).first, const Offset(0, -2500));
      await beat(tester, 1200);
      await tester.drag(find.byType(ListView).first, const Offset(0, -2500));
      await beat(tester, 1200);
      expect(tester.takeException(), isNull);
    });
  });

  group('onboarding', () {
    testWidgets('walks all six steps and creates the profile',
        (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.caregiver);
      await tester.pumpWidget(harness(const PatientOnboardingFlow(), state: state));
      await beat(tester);

      expect(find.text('STEP 1 / 6'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await beat(tester);

      // Step 2 requires at least one person.
      expect(find.text('STEP 2 / 6'), findsOneWidget);
      await tester.dragUntilVisible(
        find.text('Add everyone at once'),
        find.byType(ListView).last,
        const Offset(0, -120),
      );
      await beat(tester);
      await tester.tap(find.text('Add everyone at once'));
      await beat(tester);
      await tester.tap(find.text('Continue'));
      await beat(tester);

      // Step 3 requires at least one memory.
      expect(find.text('STEP 3 / 6'), findsOneWidget);
      await tester.tap(find.text('Fill in the suggested answers'));
      await beat(tester);
      await tester.tap(find.text('Continue'));
      await beat(tester);

      // Step 4 requires at least one photograph.
      expect(find.text('STEP 4 / 6'), findsOneWidget);
      await tester.tap(find.text('Select all'));
      await beat(tester);
      await tester.tap(find.text('Continue'));
      await beat(tester);

      expect(find.text('STEP 5 / 6'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await beat(tester);

      expect(find.text('STEP 6 / 6'), findsOneWidget);
      await tester.tap(find.text('Create her companion'));
      await beat(tester, 1200);

      expect(find.textContaining('companion is ready'), findsOneWidget);
      expect(state.patient.family.length, 4);
      expect(state.patient.assets.length, 12);
      expect(tester.takeException(), isNull);
    });
  });

  group('every activity opens and plays', () {
    testWidgets('procedure reconstruction', (WidgetTester tester) async {
      tester.setSurface(kPhone);
      await tester.pumpWidget(harness(const ProcedureGame()));
      await beat(tester);
      expect(find.text('Making tea'), findsOneWidget);

      await tester.tap(find.text('Show me the steps'));
      await beat(tester);
      for (int i = 0; i < 4; i++) {
        final Finder next = find.text('Next step');
        if (next.evaluate().isEmpty) break;
        await tester.tap(next);
        await beat(tester);
      }
      await tester.tap(find.text('I am ready'));
      await beat(tester);
      expect(find.text('THE SEQUENCE SO FAR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('finish the story', (WidgetTester tester) async {
      tester.setSurface(kPhone);
      await tester.pumpWidget(harness(const StoryGame()));
      await beat(tester);
      expect(find.text('CHOOSE WHAT HAPPENS NEXT'), findsOneWidget);

      await tester.tap(find.text('She shared the vegetables with her neighbour.'));
      await beat(tester, 1400);
      expect(find.text('HOW MITRA READ IT'), findsOneWidget);
      await tester.tap(find.text('Next story'));
      await beat(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('familiar place explorer · phone and tablet landscape',
        (WidgetTester tester) async {
      for (final Size size in <Size>[kPhone, kTabletLandscape]) {
        tester.setSurface(size);
        await tester.pumpWidget(
          harness(FamiliarPlaceGame(key: ValueKey<Size>(size))),
        );
        await beat(tester);
        expect(find.text('REMEMBER THESE'), findsOneWidget);

        await tester.tap(find.text('I will remember them'));
        await beat(tester);
        expect(find.text('THINGS IN THIS ROOM'), findsOneWidget);
        expect(find.text('Wall clock'), findsWidgets);

        await tester.tap(find.text('Next room'));
        await beat(tester, 800);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('melody of the valleys', (WidgetTester tester) async {
      tester.setSurface(kPhone);
      await tester.pumpWidget(harness(const MelodyGame()));
      await beat(tester);
      expect(find.text('Dhol'), findsWidgets);

      await tester.tap(find.text('Play the tune'));
      await beat(tester, 4000);
      expect(find.text('Play it again'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('weaves of the hills', (WidgetTester tester) async {
      tester.setSurface(kPhone);
      await tester.pumpWidget(harness(const WeavesGame()));
      // Level 3 starts with a timed preview.
      await beat(tester, 8000);
      expect(find.text('CHOOSE THE MISSING PIECE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ner memory cards', (WidgetTester tester) async {
      tester.setSurface(kPhone);
      await tester.pumpWidget(harness(const MemoryCardsGame()));
      await beat(tester);
      expect(find.text('Pairs found'), findsOneWidget);
      expect(find.text('0 / 6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('accessibility settings apply live', () {
    testWidgets('extra-large text does not break the patient home screen',
        (WidgetTester tester) async {
      tester.setSurface(kPhoneSmall);
      final AppState state = AppState()
        ..setRole(AppRole.patient)
        ..textSize = TextSizePreference.extraLarge
        ..highContrast = true;

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.warm(highContrast: true),
            home: const PatientShell(),
            builder: (BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(state.textSize.scale)),
              child: child!,
            ),
          ),
        ),
      );
      await beat(tester);
      expect(tester.takeException(), isNull);

      for (final String tab in <String>['Activities', 'Progress', 'Profile']) {
        await tester.tap(find.text(tab).last);
        await beat(tester);
        expect(tester.takeException(), isNull, reason: '$tab broke at extra-large text');
      }
    });
  });

  group('state ripples across roles', () {
    testWidgets('a mood check-in shows up on the caregiver dashboard',
        (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.patient);

      await tester.pumpWidget(harness(const PatientShell(), state: state));
      await beat(tester);
      await tester.tap(find.text('Good').first);
      await beat(tester);
      expect(state.mood, isNotNull);
      expect(state.journeyDone.contains('checkin'), isTrue);

      await tester.pumpWidget(harness(const CaregiverShell(), state: state));
      await beat(tester, 1200);
      expect(find.textContaining('Good'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
