import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smaran_saathi/app/theme/app_theme.dart';
import 'package:smaran_saathi/core/services/app_state.dart';
import 'package:smaran_saathi/features/caregiver/caregiver_shell.dart';
import 'package:smaran_saathi/features/doctor/chat/doctor_chat_conversation_screen.dart';
import 'package:smaran_saathi/core/models/doctor.dart';
import 'package:smaran_saathi/features/caregiver/doctor/doctor_care_screen.dart';
import 'package:smaran_saathi/features/caregiver/patient_view_screen.dart';
import 'package:smaran_saathi/features/doctor/doctor_shell.dart';
import 'package:smaran_saathi/features/doctor/profile/doctor_profile_screen.dart';
import 'package:smaran_saathi/features/doctor/patients/patient_detail_screen.dart';
import 'package:smaran_saathi/features/patient/games/familiar_place/familiar_place_game.dart';
import 'package:smaran_saathi/features/patient/games/melody/melody_game.dart';
import 'package:smaran_saathi/features/patient/games/memory_cards/memory_cards_game.dart';
import 'package:smaran_saathi/features/patient/games/procedure/procedure_game.dart';
import 'package:smaran_saathi/features/patient/games/story/story_game.dart';
import 'package:smaran_saathi/features/patient/games/weaves/weaves_game.dart';
import 'package:smaran_saathi/core/models/game.dart';
import 'package:smaran_saathi/features/patient/games/mood_canvas/mood_canvas_game.dart';
import 'package:smaran_saathi/features/patient/games/mood_canvas/mood_canvas_painter.dart';
import 'package:smaran_saathi/features/patient/memories/memory_wallet_screen.dart';
import 'package:smaran_saathi/features/patient/health/health_dashboard_screen.dart';
import 'package:smaran_saathi/features/patient/assistant/assistant_screen.dart';
import 'package:smaran_saathi/features/patient/patient_shell.dart';
import 'package:smaran_saathi/core/widgets/ui_kit.dart';
import 'package:smaran_saathi/l10n/locale_controller.dart';

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
    // The running app always provides one, and `LanguageSelector` renders
    // nothing without it — so a harness that left it out could not see the
    // language picker at all.
    child: LocaleScope(
      controller: LocaleController(),
      child: MaterialApp(
      debugShowCheckedModeBanner: false,
        theme: AppTheme.warm(),
        home: child,
      ),
    ),
  );
}

/// Pump without settling — the companion animates forever.
Future<void> beat(WidgetTester tester, [int ms = 500]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

/// Dismisses the "quick note for the doctor" prompt `CaregiverShell` shows
/// once per session when nothing has been logged yet this cycle — a fresh
/// `AppState` always starts in that state, so every caregiver-shell test
/// meets it. Most of those tests want to interact with the shell itself, not
/// this prompt, so they dismiss it immediately the way a caregiver tapping
/// "Not now" would.
Future<void> dismissCaregiverNotePrompt(WidgetTester tester) async {
  await tester.pump();
  final Finder notNow = find.text('Not now');
  if (notNow.evaluate().isNotEmpty) {
    await tester.tap(notNow);
    await tester.pump();
  }
}

/// Taps a destination on the caregiver bottom bar.
///
/// There is no drawer any more, so this is how every caregiver test moves
/// between pages.
Future<void> goToTab(WidgetTester tester, String label) async {
  final Finder tab = find.text(label);
  expect(tab, findsWidgets, reason: '$label is not on the bottom bar');
  await tester.tap(tab.last);
  await beat(tester);
}

/// Scrolls the visible page's list until [text] is built.
///
/// A long page's `ListView` only builds what is near the viewport, so a row
/// half a screen down is not merely off-screen — it does not exist yet, and
/// `ensureVisible` throws rather than scrolling to it.
Future<void> scrollTo(WidgetTester tester, String text) async {
  final Finder list = find.byType(ListView).first;
  for (int i = 0; i < 20 && find.text(text).evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -400));
    await beat(tester);
  }
  expect(find.text(text), findsWidgets, reason: '$text never came into view');

  // Built is not the same as tappable: a row that has just appeared sits at
  // the bottom of the viewport, where the floating voice button covers it.
  // Keep going until it is clear of that corner.
  final double height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  for (int i = 0; i < 6 && tester.getCenter(find.text(text).first).dy > height - 220; i++) {
    await tester.drag(list, const Offset(0, -140));
    await beat(tester);
  }
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
  dashboardScrollTests();

  group('patient shell renders on every size', () {
    for (final (String name, Size size) in <(String, Size)>[
      ('small phone', kPhoneSmall),
      ('phone', kPhone),
      ('large phone', kPhoneLarge),
      ('tablet', kTablet),
    ]) {
      testWidgets('all three tabs · $name', (WidgetTester tester) async {
        tester.setSurface(size);
        final AppState state = AppState()..setRole(AppRole.patient);
        await tester.pumpWidget(harness(const PatientShell(), state: state));
        await beat(tester);

        // Progress is no longer a destination: it lives on the home screen,
        // under the status it explains. Nor is the profile — that moved to
        // the top right of the header, beside reminders. The Companion page
        // was also removed from the bar; the assistant opens via push.
        for (final String tab in <String>[
          'Activities',
          'Wellness',
          'Home',
        ]) {
          await tester.tap(find.text(tab).last);
          await beat(tester);
          expect(tester.takeException(), isNull, reason: '$tab overflowed on $name');
        }

        // Both header actions are present and open their own screen.
        for (final IconData icon in <IconData>[
          Icons.notifications_none_rounded,
          Icons.person_outline_rounded,
        ]) {
          await tester.tap(find.byIcon(icon).first);
          await beat(tester, 800);
          expect(tester.takeException(), isNull, reason: '$icon overflowed on $name');
          await tester.pageBack();
          await beat(tester);
        }
      });
    }

    testWidgets('the check-in offers to talk, and the offer pushes the companion',
        (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.patient);
      await tester.pumpWidget(harness(const PatientShell(), state: state));
      await beat(tester);

      // Asked once, not twice.
      expect(find.byKey(const Key('home_mood_picker')), findsOneWidget);

      // Nothing is offered until there is a mood to talk about.
      expect(find.text('Talk to Mitra'), findsNothing);

      await scrollTo(tester, 'Not good');
      await tester.tap(find.text('Not good').last);
      await beat(tester);

      // The offer reads as a person would say it, and it is an offer — the
      // screen does not move on its own.
      expect(find.text('Talk to Mitra'), findsOneWidget);
      expect(find.text('You do not have to carry it on your own.'), findsOneWidget);

      await scrollTo(tester, 'Talk to Mitra');
      await tester.tap(find.text('Talk to Mitra'));
      await beat(tester, 900);
      expect(find.byType(AssistantScreen), findsOneWidget);
    });
  });

  group('patient preview', () {
    testWidgets('the back arrow leaves the preview from inside the patient app',
        (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.caregiver);
      await tester.pumpWidget(harness(const PatientViewScreen(), state: state));
      await beat(tester);

      expect(find.text("You are viewing the patient's app"), findsOneWidget);
      expect(state.viewingAsPatient, isTrue);

      // The cross/close button was removed deliberately (the banner is meant
      // to stay up, with no way to dismiss just the banner) — the back arrow
      // is now the only way out, so it alone has to carry the "always a way
      // back" guarantee this screen's own class doc comment promises.
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      // Go a screen deeper inside the preview — the patient's app has its
      // own nested navigator, so this stays inside the preview instead of
      // touching the caregiver's own stack, and the banner keeps showing.
      await tester.tap(find.byIcon(Icons.person_outline_rounded).first);
      await beat(tester, 600);
      expect(find.text("You are viewing the patient's app"), findsOneWidget);

      // The second arrow is the patient app's own back button, showing
      // because there is genuinely a page to return to inside that nested
      // stack — tapping it stays inside the preview.
      expect(find.byIcon(Icons.arrow_back_rounded), findsNWidgets(2));
      await tester.tap(find.byIcon(Icons.arrow_back_rounded).last);
      await beat(tester, 600);
      expect(state.viewingAsPatient, isTrue);

      // Back at the patient's root tab, only the banner's own arrow remains
      // — and only it ends the preview.
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await beat(tester, 600);

      // Out of the preview entirely, and the caregiver has their own role back.
      expect(find.text("You are viewing the patient's app"), findsNothing);
      expect(state.viewingAsPatient, isFalse);
      expect(state.role, AppRole.caregiver);
    });
  });

  group('doctor directory', () {
    testWidgets('a caregiver can browse doctors and connect to one',
        (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.caregiver);
      await tester.pumpWidget(harness(const DoctorCareScreen(), state: state));
      await beat(tester, 800);

      // One doctor is connected out of the box, so the directory is not shown
      // until that connection is ended — and ending it has to be reachable
      // from the screen, not just from the state.
      expect(state.connectedDoctor, isNotNull);
      await scrollTo(tester, 'Disconnect');
      await tester.tap(find.text('Disconnect').first);
      await beat(tester, 600);
      expect(find.textContaining('Disconnect Dr.'), findsOneWidget);
      await tester.tap(find.text('Disconnect').last);
      await beat(tester, 600);
      expect(state.connectedDoctor, isNull);

      await scrollTo(tester, 'Doctors near you');
      expect(find.text('Doctors near you'), findsOneWidget);

      // More than the one hardcoded clinician this screen used to carry, and
      // a spread of specialisations rather than six neurologists.
      expect(state.doctorDirectory.length, greaterThan(3));
      expect(
        state.doctorDirectory.map((DoctorProfile d) => d.specialization).toSet().length,
        greaterThan(3),
      );

      // Inviting one, then accepting on their behalf, connects it — and
      // connecting is what brings the booking section back.
      final DoctorProfile pick = state.doctorDirectory
          .firstWhere((DoctorProfile d) => d.status == InvitationStatus.notSent);
      state.inviteDoctor(pick.id);
      await beat(tester, 400);
      expect(state.doctorDirectory.firstWhere((DoctorProfile d) => d.id == pick.id).status,
          InvitationStatus.sent);

      // "Invitation sent" and "Pending" are one state to the caregiver: they
      // have written, and they are waiting.
      expect(InvitationStatus.sent.label, InvitationStatus.pending.label);
      expect(InvitationStatus.sent.label, 'Waiting for reply');
      expect(find.text('Waiting for reply'), findsWidgets);

      // The caregiver cannot connect a doctor themselves — no button on this
      // screen does it, because agreeing is the doctor's to give.
      expect(find.text('Connect now'), findsNothing);
      expect(state.connectedDoctor, isNull);

      // The invitation turns up on the doctor's side, and accepting it there
      // is what connects them here.
      final ConnectionRequest request = state.connectionRequests
          .firstWhere((ConnectionRequest r) => r.doctorId == pick.id);
      state.acceptConnectionRequest(request.id);
      await beat(tester, 400);
      expect(state.connectedDoctor?.id, pick.id);

      // Only ever one, or two clinicians would each think they hold the plan.
      expect(
        state.doctorDirectory
            .where((DoctorProfile d) => d.status == InvitationStatus.connected)
            .length,
        1,
      );
    });
  });

  group('doctor account', () {
    testWidgets('the profile separates switching role from logging out',
        (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.doctor);
      await tester.pumpWidget(harness(const DoctorProfileScreen(), state: state));
      await beat(tester, 800);

      // Two actions, not one. The single button used to sign a clinician out
      // of their account just to look at another side of the app.
      await scrollTo(tester, 'Log out');
      expect(find.text('Log out'), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);

      // Log out asks first, and does nothing until it is confirmed.
      await tester.tap(find.text('Log out'));
      await beat(tester, 600);
      expect(find.text('Log out?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await beat(tester, 600);
      expect(state.role, AppRole.doctor);
    });
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
      testWidgets('all caregiver destinations · $name', (WidgetTester tester) async {
        tester.setSurface(size);
        final AppState state = AppState()..setRole(AppRole.caregiver);
        await tester.pumpWidget(harness(const CaregiverShell(), state: state));
        await dismissCaregiverNotePrompt(tester);
      await dismissCaregiverNotePrompt(tester);
        await beat(tester);

        // Every destination on the bar, then back to the dashboard.
        for (final String dest in <String>[
          'Family',
          'Doctors',
          'Reports',
          'Dashboard',
        ]) {
          await goToTab(tester, dest);
          await beat(tester, 1200);
          expect(tester.takeException(), isNull, reason: '$dest overflowed on $name');
        }

        // Reminders and the profile moved to the header.
        for (final IconData icon in <IconData>[
          Icons.notifications_none_rounded,
          Icons.person_outline_rounded,
        ]) {
          await tester.tap(find.byIcon(icon).first);
          await beat(tester, 1200);
          expect(tester.takeException(), isNull, reason: '$icon overflowed on $name');
        }
      });
    }

    testWidgets('memory profile sub-tabs render', (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.caregiver);
      await tester.pumpWidget(harness(const CaregiverShell(), state: state));
      await dismissCaregiverNotePrompt(tester);
      await beat(tester);
      await goToTab(tester, 'Family');

      final Finder chips = find.byKey(const Key('profile-tabs'));
      for (final String tab in <String>['Memories', 'Photographs', 'Routine', 'People']) {
        await tapChip(tester, chips, tab);
        expect(tester.takeException(), isNull, reason: '$tab overflowed');
      }
    });

    testWidgets('the overview leads with what needs attention, not a patient card',
        (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.caregiver);
      await tester.pumpWidget(harness(const CaregiverShell(), state: state));
      await dismissCaregiverNotePrompt(tester);
      await beat(tester);

      // The patient hero card is gone: the profile has its own tab, and the
      // name now rides along in the greeting.
      expect(find.text('YOUR PATIENT'), findsNothing);

      // Today's numbers appear once, not twice — the glance grid replaced the
      // duplicate overview rows underneath it.
      expect(find.text('Activities completed'), findsOneWidget);

      // The onboarding is offered rather than forced, so it leads the
      // attention list until it is answered.
      expect(find.text('Finish setting up'), findsOneWidget);

      // Safe zone has a section of its own, in the state that matters most
      // on a fresh install: there is no boundary yet, so no alert can fire.
      await scrollTo(tester, 'No safe zone yet');
      expect(find.text('Safe zone'), findsOneWidget);
      expect(find.text('No safe zone yet'), findsOneWidget);
      expect(find.text('Set a safe zone'), findsOneWidget);

      // And nothing is invented: the old canned "improving" note is gone.
      expect(find.text('Procedural activities are improving'), findsNothing);

      // The Patient Progress tab is gone: with one patient to one caregiver
      // its analytics belong on this screen, and they are all here — further
      // down, so the list has to be scrolled to reach them. Scrolled last,
      // because everything asserted above unmounts on the way past.
      final Finder list = find.byType(ListView).first;
      for (final String section in <String>[
        'Engagement this week',
        'Daily cognitive engagement',
        'Activities completed each day',
        'Recent sessions',
      ]) {
        while (find.text(section).evaluate().isEmpty) {
          await tester.drag(list, const Offset(0, -400));
          await beat(tester);
        }
        expect(find.text(section), findsOneWidget);
      }
    });

    testWidgets('every memory-profile record can be created',
        (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.caregiver);
      await tester.pumpWidget(harness(const CaregiverShell(), state: state));
      await dismissCaregiverNotePrompt(tester);
      await beat(tester);
      await goToTab(tester, 'Family');

      final Finder chips = find.byKey(const Key('profile-tabs'));

      // Each tab offers a way to add a record of its own — People could only
      // pick from a fixed sample list, and the other three were read-only.
      for (final (String, String) pair in <(String, String)>[
        ('People', 'Add a person'),
        ('Memories', 'Add a memory'),
        ('Photographs', 'Add a picture'),
        ('Routine', 'Add to the day'),
      ]) {
        await tapChip(tester, chips, pair.$1);
        await scrollTo(tester, pair.$2);
        expect(find.text(pair.$2), findsWidgets, reason: '${pair.$1} cannot add');
      }

      // And the create sheet really takes free text, rather than offering a
      // list of sample relatives to choose from.
      await tapChip(tester, chips, 'People');
      await scrollTo(tester, 'Add a person');
      await tester.tap(find.text('Add a person').last);
      await beat(tester);
      expect(find.text('Their name'), findsOneWidget);
      expect(find.text('Relation'), findsOneWidget);

      // A real photograph, with the drawing kept as the fallback for when
      // the file is gone.
      expect(find.text('Photograph'), findsOneWidget);
      expect(find.text('Choose'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('How should they be drawn?'), findsOneWidget);
    });

    testWidgets('the safe zone page wears the app\'s own chrome',
        (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.caregiver);
      await tester.pumpWidget(harness(const CaregiverShell(), state: state));
      await dismissCaregiverNotePrompt(tester);
      await scrollTo(tester, 'Set a safe zone');
      await tester.tap(find.text('Set a safe zone'));
      await beat(tester);

      // The shell already draws a header; the page must not add a second one.
      expect(find.byType(AppBar), findsNothing);

      // No stock Material buttons left on the one caregiver screen that had
      // them — the app's own BigButton does the work now.
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);

      // The map is the page: with no zone drawn, nothing is stacked above it
      // explaining that none is drawn. The only thing offered is the action.
      expect(find.text('No safe zone yet'), findsNothing);
      expect(find.text('Set a safe zone'), findsWidgets);

      // Every map control has to be on screen and clear of the controls
      // sheet, not merely present in the tree — pinning one to `bottom`
      // behind a full-width sheet drawn after it made it invisible.
      final Rect sheet = tester.getRect(find.text('Set a safe zone'));
      for (final IconData icon in <IconData>[
        Icons.my_location_rounded,
        Icons.add_rounded,
        Icons.remove_rounded,
      ]) {
        final Finder button = find.byIcon(icon);
        expect(button, findsOneWidget, reason: '$icon is missing');
        expect(tester.getRect(button).bottom, lessThanOrEqualTo(sheet.top),
            reason: '$icon is hidden behind the controls sheet');
      }
    });

    testWidgets('the caregiver profile names the caregiver and offers a way out',
        (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.caregiver);
      await tester.pumpWidget(harness(const CaregiverShell(), state: state));
      await dismissCaregiverNotePrompt(tester);
      await beat(tester);

      await tester.tap(find.byIcon(Icons.person_outline_rounded).first);
      await beat(tester);

      // Their own details, editable rather than fixed at onboarding time.
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      // Language now lives here too — the caregiver sets the phone up, and
      // the picker used to be reachable only from the patient's settings.
      await scrollTo(tester, 'English');
      expect(find.text('English'), findsWidgets);

      // And a log out that does not depend on an auth service being wired:
      // `AccountSection` collapses to nothing without one, so this section
      // has to stand on its own.
      // Exactly one of each: an "Account" heading, a signed-in email and a
      // log out button all used to appear twice on this page.
      await scrollTo(tester, 'Log out');
      expect(find.text('Log out'), findsOneWidget);
      expect(find.text('Switch to another role'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
    });

  });

  group('doctor shell', () {
    for (final (String name, Size size) in <(String, Size)>[
      ('small phone', kPhoneSmall),
      ('phone', kPhone),
      ('tablet', kTablet),
    ]) {
      testWidgets('all tabs · $name', (WidgetTester tester) async {
        tester.setSurface(size);
        final AppState state = AppState()..setRole(AppRole.doctor);
        await tester.pumpWidget(harness(const DoctorShell(), state: state));
        await beat(tester, 1200);

        for (final String tab in <String>[
          'Patients',
          'Chats',
          'Appointments',
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
      await tester.scrollUntilVisible(find.text('Cognitive profile'), 300);
      expect(find.text('Cognitive profile'), findsOneWidget);

      // Scroll the whole record to force every card through layout.
      await tester.drag(find.byType(ListView).first, const Offset(0, -2500));
      await beat(tester, 1200);
      await tester.drag(find.byType(ListView).first, const Offset(0, -2500));
      await beat(tester, 1200);
      expect(tester.takeException(), isNull);
    });

    testWidgets('doctor chat screen renders and sends message', (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.doctor);
      await tester.pumpWidget(
        harness(const DoctorChatConversationScreen(patientId: 'p_aama'), state: state),
      );
      await beat(tester, 1200);
      expect(find.text('Aama Devi'), findsOneWidget);
      expect(find.textContaining('Messages are end-to-end encrypted'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Hello from Doctor');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await beat(tester, 1200);
      expect(find.text('Hello from Doctor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });


  group('every activity opens and plays', () {
    testWidgets('procedure reconstruction', (WidgetTester tester) async {
      tester.setSurface(kPhone);
      await tester.pumpWidget(harness(const ProcedureGame()));
      await beat(tester);
      // A new account starts at level 1, so "Making tea" now appears twice:
      // once as the level-1 chip's own label, and again as the selected
      // procedure's heading, since level 1 is what's actually selected.
      expect(find.text('Making tea'), findsWidgets);

      await tester.tap(find.text('Show me the steps'));
      await beat(tester);
      await tester.tap(find.text('I am ready to build'));
      await beat(tester);
      expect(find.text('THE SEQUENCE SO FAR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('finish the story', (WidgetTester tester) async {
      tester.setSurface(kPhone);
      await tester.pumpWidget(harness(const StoryGame()));
      await beat(tester);
      await tester.tap(find.text('Start story'));
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
        await tester.tap(find.byType(BigButton));
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
      // Intro screen first, same as every other activity.
      await tester.tap(find.text('Start game'));
      await beat(tester);
      expect(find.text('Pairs found'), findsOneWidget);
      expect(find.textContaining('0 /'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mood check-in', (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState();
      await tester.pumpWidget(harness(const MoodCanvasGame(), state: state));
      await beat(tester);
      await tester.tap(find.text('Start drawing'));
      await beat(tester);

      // Next starts disabled — nothing has been drawn yet.
      expect(tester.widget<BigButton>(find.widgetWithText(BigButton, 'Next')).onPressed, isNull);

      await tester.drag(
        find.byWidgetPredicate((Widget w) => w is CustomPaint && w.painter is MoodCanvasPainter),
        const Offset(60, 40),
      );
      await beat(tester);
      expect(tester.widget<BigButton>(find.widgetWithText(BigButton, 'Next')).onPressed,
          isNotNull);

      // `toImage()`/`toByteData()` hit the real rasterizer, not a fake-clock
      // timer — `runAsync` escapes the FakeAsync test zone so real engine
      // work can actually complete, which plain `pump()` cannot drive.
      await tester.tap(find.text('Next'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await beat(tester);

      // The check-in phase opens with the fixed opening question, and no
      // network/model is configured in a test environment, so every answer
      // is handled by the deterministic on-device fallback.
      expect(find.text('How are you feeling right now?'), findsOneWidget);
      for (int i = 0; i < 3; i++) {
        await tester.enterText(find.byType(TextField), 'fine, thank you');
        await tester.tap(find.byIcon(Icons.send_rounded));
        await beat(tester);
      }

      expect(find.text('Talk more with Mitra'), findsOneWidget);
      expect(state.moodDrawings, hasLength(1));
      expect(state.moodDrawings.first.transcript, hasLength(3));
      expect(state.completedToday, contains(GameId.moodCanvas));
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

      for (final String tab in <String>['Activities', 'Wellness']) {
        await tester.tap(find.text(tab).last);
        await beat(tester);
        final dynamic err = tester.takeException();
        expect(err, isNull, reason: '$tab broke at extra-large text');
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
      // The mood picker now sits below the session card, so it has to be
      // scrolled to — and matched inside the picker, since "Good" appears
      // elsewhere on the screen too.
      // Find 'Good' strictly inside the home MoodPicker (keyed to avoid
      // ambiguity when IndexedStack keeps all five tabs alive simultaneously).
      final Finder good = find.descendant(
        of: find.byKey(const Key('home_mood_picker')),
        matching: find.text('Good'),
      ).first;
      // `ensureVisible`, not `scrollUntilVisible`: the picker is already built
      // (the ListView builds a little past the fold), so a finder-based scroll
      // stops immediately and leaves it sitting below the screen edge.
      await tester.ensureVisible(good);
      await beat(tester);
      await tester.tapAt(tester.getCenter(good));

      await beat(tester);
      expect(state.mood, isNotNull);
      expect(state.journeyDone.contains('checkin'), isTrue);

      await tester.pumpWidget(harness(const CaregiverShell(), state: state));
      await dismissCaregiverNotePrompt(tester);
      await beat(tester, 1200);
      expect(find.textContaining('Good'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}

/// The home page carries the whole record, so getting back to the top of it
/// has to be one action rather than six flicks.
void dashboardScrollTests() {
  group('the home page stays navigable', () {
    testWidgets('the progress detail is collapsed until asked for',
        (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.patient);
      addTearDown(state.dispose);
      await state.loadDemoJourney(now: DateTime(2026, 8, 29));

      await tester.pumpWidget(
        harness(const HealthDashboardScreen(), state: state),
      );
      await beat(tester);

      expect(find.text('Why did my score change?'), findsNothing,
          reason: 'the detail is behind one tap, so the page stays short');
      expect(find.text('By domain'), findsNothing);

      final Finder more = find.textContaining('areas');
      await tester.dragUntilVisible(
        more,
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      await beat(tester);
      await tester.tap(more);
      await beat(tester);

      expect(find.text('By domain'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a back-to-top button appears once the top is far away',
        (WidgetTester tester) async {
      tester.setSurface(kPhone);
      final AppState state = AppState()..setRole(AppRole.patient);
      addTearDown(state.dispose);
      await state.loadDemoJourney(now: DateTime(2026, 8, 29));

      await tester.pumpWidget(
        harness(const HealthDashboardScreen(), state: state),
      );
      await beat(tester);
      expect(find.byType(FloatingActionButton), findsNothing);

      final Finder list = find.byType(Scrollable).first;
      await tester.fling(list, const Offset(0, -1400), 2200);
      await beat(tester);
      await beat(tester);

      expect(find.byType(FloatingActionButton), findsOneWidget,
          reason: 'the way back appears once scrolling back would be work');

      await tester.tap(find.byType(FloatingActionButton));
      await beat(tester);
      await beat(tester);

      expect(find.byType(FloatingActionButton), findsNothing,
          reason: 'and it takes you back to the top, where it is not needed');
      expect(tester.takeException(), isNull);
    });
  });
}
