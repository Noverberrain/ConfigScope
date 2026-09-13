///|
/// Explicit legacy facade for the original general configuration APIs.
///
/// These APIs remain available for migration experiments, but they are not
/// part of the primary ConfigScope compatibility workflow.
pub using @core {
  type ConfigAuditIssue,
  type ConfigAuditIssueKind,
  type ConfigAuditRule,
  type ConfigConflict,
  type ConfigExplanation,
  type ConfigLayer,
  type LayeredConfig,
  type LayeredMergeResult,
  type MergeResult,
}
