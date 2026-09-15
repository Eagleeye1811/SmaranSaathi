/// Shared formatting for consultation report data, so every screen that
/// renders a [ConsultationSession] (doctor review, patient/caregiver view,
/// doctor's patient history) describes the same session the same way.
library;

const List<String> _months = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String formatConsultationDate(DateTime date) {
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

String formatConsultationDuration(int seconds) {
  return '${seconds ~/ 60}m ${seconds % 60}s';
}
