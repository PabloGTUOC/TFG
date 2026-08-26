import '../l10n/app_localizations.dart';

/// Starter-task catalogue for new families
/// (docs/family-setup-questionnaire-plan.md).
///
/// Titles resolve through [AppLocalizations], so a family is seeded in the
/// language the app is running in — this is what the backend's English-only
/// `defaultActivities.js` could never do, since those are database rows
/// rather than UI strings. Once created they are ordinary user-editable
/// tasks: switching app language later does not re-translate them.
///
/// Tasks are grouped by activity area so Stage B's questionnaire can offer
/// them as selectable packs. Stage A derives the areas from the dependents
/// entered in the wizard ([areasForDependents]).

/// One seedable task. [title] resolves the localized name at build time.
class StarterTask {
  final String Function(AppLocalizations) title;

  /// 'care' | 'household' — the care subclass's types in the activities CHECK.
  final String type;
  final int durationMinutes;
  final bool isRecurrent;

  const StarterTask(this.title, this.type, this.durationMinutes,
      {this.isRecurrent = false});

  Map<String, dynamic> toPayload(AppLocalizations l) => {
        'title': title(l),
        'type': type,
        'durationMinutes': durationMinutes,
        'isRecurrent': isRecurrent,
      };
}

/// Activity areas — Stage B's multi-select options.
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

/// Areas every family gets regardless of who they care for.
const kUniversalAreas = {
  StarterArea.meals,
  StarterArea.cleaning,
  StarterArea.errands,
};

final Map<StarterArea, List<StarterTask>> starterPacks = {
  StarterArea.meals: [
    StarterTask((l) => l.taskBreakfastPrep, 'household', 30, isRecurrent: true),
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
    StarterTask((l) => l.taskNightWakeUp, 'care', 30),
  ],
  StarterArea.pets: [
    StarterTask((l) => l.taskMorningWalk, 'care', 30, isRecurrent: true),
    StarterTask((l) => l.taskEveningWalk, 'care', 30, isRecurrent: true),
    StarterTask((l) => l.taskPetFeeding, 'care', 30, isRecurrent: true),
  ],
  StarterArea.elderCare: [
    StarterTask((l) => l.taskDoctorAccompany, 'care', 90),
    StarterTask((l) => l.taskMedicationReminder, 'care', 30, isRecurrent: true),
  ],
};

/// Which areas apply to the dependents entered in the wizard. Replaces the
/// backend's actor-type mapping, and is the implicit questionnaire until
/// Stage B lets people choose explicitly.
Set<StarterArea> areasForDependents(Iterable<String> dependentTypes) {
  final areas = {...kUniversalAreas};
  for (final raw in dependentTypes) {
    switch (raw.toLowerCase()) {
      case 'child':
      case 'baby':
      case 'toddler':
        areas.addAll({
          StarterArea.kidsRoutines,
          StarterArea.homework,
          StarterArea.nightCare,
        });
      case 'pet':
      case 'dog':
      case 'cat':
        areas.add(StarterArea.pets);
      case 'elderly':
        areas.add(StarterArea.elderCare);
    }
  }
  return areas;
}

/// Human label for an area chip in the setup questionnaire.
String starterAreaLabel(AppLocalizations l, StarterArea area) =>
    switch (area) {
      StarterArea.meals => l.areaMeals,
      StarterArea.cleaning => l.areaCleaning,
      StarterArea.errands => l.areaErrands,
      StarterArea.kidsRoutines => l.areaKidsRoutines,
      StarterArea.homework => l.areaHomework,
      StarterArea.nightCare => l.areaNightCare,
      StarterArea.pets => l.areaPets,
      StarterArea.elderCare => l.areaElderCare,
    };

/// One row of the questionnaire's preview list.
typedef StarterEntry = ({StarterArea area, int index, StarterTask task});

/// Stable identity for a task across rebuilds and language switches — the
/// localized title is not usable as a key because it changes with the locale.
String starterTaskKey(StarterArea area, int index) => '${area.name}:$index';

/// The tasks implied by [areas], in a stable display order.
List<StarterEntry> starterEntries(Set<StarterArea> areas) => [
      for (final area in StarterArea.values)
        if (areas.contains(area))
          for (final (index, task) in starterPacks[area]!.indexed)
            (area: area, index: index, task: task),
    ];

/// Builds the `starterTasks` payload for `POST /api/families`, localized
/// through [l]. Areas keep their declaration order so the seeded catalogue
/// reads sensibly in the activity library. [excluded] holds
/// [starterTaskKey] values the user unchecked in the preview.
List<Map<String, dynamic>> starterTasksPayload(
  AppLocalizations l,
  Set<StarterArea> areas, {
  Set<String> excluded = const {},
}) =>
    [
      for (final entry in starterEntries(areas))
        if (!excluded.contains(starterTaskKey(entry.area, entry.index)))
          entry.task.toPayload(l),
    ];
