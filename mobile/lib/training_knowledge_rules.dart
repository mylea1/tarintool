import 'models.dart';

/// Deterministic, offline training rules shared by the home recommendation
/// surface and the server-backed AI plan flow.
///
/// These values intentionally mirror the guardrails in
/// `backend/knowledge/training-framework.zh-CN.json`: use completed sets as
/// evidence, protect recently-stimulated muscles, and prefer recovery-aware
/// volume balancing. Keeping the small policy local means the home page does
/// not have to invent a recommendation while the network knowledge search is
/// unavailable.
class TrainingKnowledgeRules {
  const TrainingKnowledgeRules._();

  static const sourceId = 'training-framework.zh-CN';
  static const minimumRecoveryForPrimary = 60;
  static const recentStimulusCooldownHours = 36;
  static const defaultTargetMin = 8;
  static const defaultTargetMax = 12;
  static const maxPrimaryMuscles = 2;

  /// A recommendation is only personalised after at least one real completed
  /// set has been persisted. Planned/empty records are not evidence.
  static bool hasCompletedSet(Iterable<WorkoutRecord> records) =>
      records.any((record) {
        return record.exercises.any(
          (performed) => performed.sets.any((set) => set.completed),
        );
      });
}
