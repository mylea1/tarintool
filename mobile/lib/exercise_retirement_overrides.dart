/// User-requested removals live here so regenerating the scored 300-item list
/// never brings them back. Add stable exercise IDs, not visible names.
///
/// Example workflow: user says "delete 425" -> resolve catalog[424].id -> add
/// that ID below. The complete catalog still retains it for old history.
const manuallyRetiredExerciseIds = <String>{};
