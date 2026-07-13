import '../l10n/app_localizations.dart';

/// Starter-task catalogue for new families
/// (docs/family-setup-questionnaire-plan.md).
///
/// Titles resolve through [AppLocalizations], so families are seeded in the
/// user's app language — this replaces the backend's English-only
/// `defaultActivities.js` seeding for clients that send `starterTasks`.
/// Grouped by activity area so the phase-2 questionnaire can offer them as
/// selectable packs; phase 1 derives the selection from the dependents
/// entered in the wizard (same logic the backend used).

/// One seedable task. [title] resolves the localized name at build time.
class StarterTask {
  final String Function(AppLocalizations) title;
  final String category; // 'care' | 'household'
  final int durationMinutes;
  final bool isRecurrent;

  const StarterTask(this.title, this.category, this.durationMinutes,
      {this.isRecurrent = false});

  Map<String, dynamic> toPayload(AppLocalizations l) => {
        'title': title(l),
        'category': category,
        'durationMinutes': durationMinutes,
        'isRecurrent': isRecurrent,
      };
}

/// Activity areas — the future questionnaire's multi-select options.
enum StarterArea {
  meals,
  cleaning,
  errands,
  kidsRoutines,
  homework,
  nightCare,
  pets,
  elderCare,
}

final Map<StarterArea, List<StarterTask>> starterPacks = {
  StarterArea.meals: [
    StarterTask((l) => l.taskBreakfastPrep, 'household', 30,
        isRecurrent: true),
    StarterTask((l) => l.taskLunchPrep, 'household', 30, isRecurrent: true),
    StarterTask((l) => l.taskDinnerPrep, 'household', 60, isRecurrent: true),
    StarterTask((l) => l.taskDishes, 'household', 30, isRecurrent: true),
  ],
  StarterArea.cleaning: [
    StarterTask((l) => l.taskLaundry, 'household', 30),
    StarterTask((l) => l.taskHouseCleaning, 'household', 60),
  ],
  StarterArea.errands: [
    StarterTask((l) => l.taskGroceryShopping, 'household', 60),
    StarterTask((l) => l.taskPaperworkBills, 'household', 30),
  ],
  StarterArea.kidsRoutines: [
    StarterTask((l) => l.taskMorningRoutine, 'care', 60, isRecurrent: true),
    StarterTask((l) => l.taskSchoolDropoff, 'care', 30, isRecurrent: true),
    StarterTask((l) => l.taskSchoolPickup, 'care', 30, isRecurrent: true),
    StarterTask((l) => l.taskNapTime, 'care', 90, isRecurrent: true),
    StarterTask((l) => l.taskOutdoorPlay, 'care', 60, isRecurrent: true),
    StarterTask((l) => l.taskBathTime, 'care', 30, isRecurrent: true),
    StarterTask((l) => l.taskBedtimeRoutine, 'care', 60, isRecurrent: true),
  ],
  StarterArea.homework: [
    StarterTask((l) => l.taskHomeworkHelp, 'care', 60, isRecurrent: true),
  ],
  StarterArea.nightCare: [
    StarterTask((l) => l.taskNightWakeup, 'care', 30),
  ],
  StarterArea.pets: [
    StarterTask((l) => l.taskMorningWalk, 'care', 30, isRecurrent: true),
    StarterTask((l) => l.taskEveningWalk, 'care', 30, isRecurrent: true),
    StarterTask((l) => l.taskPetFeeding, 'care', 30, isRecurrent: true),
  ],
  StarterArea.elderCare: [
    StarterTask((l) => l.taskDoctorAccompany, 'care', 90),
    StarterTask((l) => l.taskMedicationReminder, 'care', 30,
        isRecurrent: true),
  ],
};

/// Areas implied by the dependents entered in the create-family wizard —
/// the phase-1 "implicit questionnaire". Mirrors the legacy backend rules
/// (household + generic care always; child/pet packs by dependent type)
/// plus the new errands pack.
Set<StarterArea> areasForDependents(Iterable<String> dependentTypes) {
  final types = dependentTypes.map((t) => t.toLowerCase()).toSet();
  final areas = <StarterArea>{
    StarterArea.meals,
    StarterArea.cleaning,
    StarterArea.errands,
    StarterArea.elderCare,
  };
  if (types.contains('child') ||
      types.contains('baby') ||
      types.contains('toddler')) {
    areas.addAll(
        [StarterArea.kidsRoutines, StarterArea.homework, StarterArea.nightCare]);
  }
  if (types.contains('pet') || types.contains('dog') || types.contains('cat')) {
    areas.add(StarterArea.pets);
  }
  return areas;
}

/// The `starterTasks` payload for POST /api/families: localized titles for
/// every task in the given areas, in stable pack order.
List<Map<String, dynamic>> buildStarterTasksPayload(
    AppLocalizations l, Set<StarterArea> areas) {
  return [
    for (final area in StarterArea.values)
      if (areas.contains(area))
        for (final task in starterPacks[area]!) task.toPayload(l),
  ];
}
