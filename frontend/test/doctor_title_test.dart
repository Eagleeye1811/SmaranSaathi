import 'package:flutter_test/flutter_test.dart';
import 'package:smaran_saathi/core/models/doctor.dart';

void main() {
  group('withDoctorTitle', () {
    test('adds the title when the name has none', () {
      expect(withDoctorTitle('Neha Sharma'), 'Dr. Neha Sharma');
      expect(withDoctorTitle('Ojha'), 'Dr. Ojha');
    });

    test('does not double the title the data already carries', () {
      // MockData.doctorName and every seeded clinician read like this.
      expect(withDoctorTitle('Dr. Neha Sharma'), 'Dr. Neha Sharma');
      expect(withDoctorTitle('Dr R. Sharma'), 'Dr R. Sharma');
      expect(withDoctorTitle('Doctor Baruah'), 'Doctor Baruah');
      expect(withDoctorTitle('prof. Hazarika'), 'prof. Hazarika');
    });

    test('is case-insensitive about the existing title', () {
      expect(withDoctorTitle('DR. BORAH'), 'DR. BORAH');
      expect(withDoctorTitle('dr. borah'), 'dr. borah');
    });

    test('a name that merely starts with those letters still gets the title', () {
      // The separator in each prefix is what keeps this from reading as a title.
      expect(withDoctorTitle('Drishti Kalita'), 'Dr. Drishti Kalita');
      expect(withDoctorTitle('Profulla Das'), 'Dr. Profulla Das');
    });

    test('trims, and survives an empty name', () {
      expect(withDoctorTitle('  Neha  '), 'Dr. Neha');
      expect(withDoctorTitle('   '), '');
      expect(withDoctorTitle(''), '');
    });

    test('applying it twice changes nothing', () {
      expect(withDoctorTitle(withDoctorTitle('Neha')), 'Dr. Neha');
    });
  });

  test('DoctorProfile.displayName no longer doubles the title', () {
    const DoctorProfile titled = DoctorProfile(
      id: 'd1', name: 'Dr. Neha Sharma', specialization: '', hospital: '',
      email: '', avatarInitials: 'N',
    );
    const DoctorProfile plain = DoctorProfile(
      id: 'd2', name: 'Ojha', specialization: '', hospital: '',
      email: '', avatarInitials: 'O',
    );
    expect(titled.displayName, 'Dr. Neha Sharma');
    expect(plain.displayName, 'Dr. Ojha');
  });
}
