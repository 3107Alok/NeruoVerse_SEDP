import 'dart:math' as math;

class DoctorClinicalThoughts {
  static const List<String> lines = [
    '“Early rural cognitive screening is the frontline shield against severe neurodegenerative decline.”',
    '“A dedicated ASHA visit can safeguard an elderly patient’s lifelong dignity and autonomy.”',
    '“Community-embedded dementia care bridges tertiary medical science with compassionate rural touch.”',
    '“Consistency in weekly village screenings transforms the clinical trajectory of memory loss in NER.”',
    '“Timely clinical triage brings specialist geriatric care directly to remote rural doorsteps.”',
    '“Empowering our frontline health workers creates the resilient foundation for public geriatric wellness.”',
    '“Every elder’s memory retained is a rich oral history of our heritage preserved.”',
    '“Proactive caregiver support reduces burnout and sustains holistic community healing.”',
  ];

  static int? _currentIndex;

  static String get thought {
    _currentIndex ??= math.Random().nextInt(lines.length);
    return lines[_currentIndex!];
  }

  static void refresh() {
    final prev = _currentIndex ?? 0;
    int next = math.Random().nextInt(lines.length);
    if (next == prev) {
      next = (next + 1) % lines.length;
    }
    _currentIndex = next;
  }
}
