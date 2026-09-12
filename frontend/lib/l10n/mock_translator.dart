import 'app_localizations.dart';

/// Helper to translate hardcoded mock data strings dynamically in the UI.
class MockTranslator {
  const MockTranslator._();

  static String translateTitle(String title, AppLocalizations l) {
    switch (title) {
      case 'Morning medicine':
        return l.mockReminderMorningMedicine;
      case 'Drink water':
        return l.mockReminderDrinkWater;
      case 'Rest and radio':
        return l.mockReminderRestAndRadio;
      case 'Evening walk':
        return l.mockReminderEveningWalk;
      case 'Call Priya':
        return l.mockReminderCallPriya;
      case 'Memory clinic — Dr. Sharma':
        return l.mockReminderMemoryClinic;
      case 'Cognitive activity':
        return l.mockReminderCognitiveActivity;
      case 'Evening medicine':
        return l.mockReminderEveningMedicine;
      default:
        return title;
    }
  }

  static String translateDetail(String detail, AppLocalizations l) {
    switch (detail) {
      case 'One tablet after breakfast':
        return l.mockDetailOneTablet;
      case 'A full glass':
        return l.mockDetailFullGlass;
      case 'With lunch':
        return l.mockDetailWithLunch;
      case 'Vividh Bharati on AIR':
        return l.mockDetailVividhBharati;
      case 'In the park with Nirmali':
        return l.mockDetailParkWithNirmali;
      case 'Check in on her day':
        return l.mockDetailCheckInDay;
      case 'Bhaskar will drive':
        return l.mockDetailBhaskarDrive;
      case 'The afternoon Bihu programme':
        return l.mockDetailAfternoonBihu;
      case 'Mitra has something ready':
        return l.mockDetailMitraReady;
      case 'Two tablets after dinner':
        return l.mockDetailTwoTablets;
      default:
        return detail;
    }
  }

  static String translateTime(String time, AppLocalizations l) {
    if (time == 'Thursday, 11:00 AM') {
      return l.mockTimeThursday11;
    }
    return time;
  }

  static String translateRelation(String relation, AppLocalizations l) {
    switch (relation) {
      case 'Daughter':
        return l.relationDaughter;
      case 'Grandson':
        return l.relationGrandson;
      case 'Son-in-law':
        return l.relationSonInLaw;
      case 'Neighbour & friend':
        return l.relationNeighbourFriend;
      default:
        return relation;
    }
  }

  static String translateFamilyNote(String note, AppLocalizations l) {
    switch (note) {
      case 'Calls every evening at 7. Lives in Guwahati.':
        return l.familyNotePriya;
      case 'Nine years old. Loves her stories about the loom.':
        return l.familyNoteAarav;
      case 'Drives her to the clinic on Thursdays.':
        return l.familyNoteBhaskar;
      case 'They have shared morning tea for thirty years.':
        return l.familyNoteNirmali;
      default:
        return note;
    }
  }

  static String translateClinicName(String clinic, AppLocalizations l) {
    if (clinic == 'Guwahati Memory Clinic') {
      return l.clinicGuwahati;
    }
    if (clinic == 'Jorhat Medical College — Memory Clinic') {
      return l.clinicJorhat;
    }
    return clinic;
  }
}
