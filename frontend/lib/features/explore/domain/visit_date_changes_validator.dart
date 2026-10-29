class VisitDateChangesValidator {
  const VisitDateChangesValidator._();

  static const _requiredFields = {
    'started_on',
    'ended_on',
    'started_on_precision',
    'ended_on_precision',
  };

  static String? validate(Map<String, dynamic> changes) {
    for (final entry in changes.entries) {
      if (_requiredFields.contains(entry.key) && entry.value == null) {
        return 'Visit dates cannot be cleared.';
      }
    }

    return null;
  }
}
