// The root package is a small facade over ConfigScope's public packages.

///|
pub using @core {
  type ConfigPath,
  type ConfigAuditIssue,
  type ConfigAuditIssueKind,
  type ConfigAuditRule,
  type ConfigPathError,
  type ConfigConflict,
  type ConfigDiff,
  type ConfigDiffKind,
  type ConfigExplanation,
  type ConfigLayer,
  type LayeredConfig,
  type LayeredMergeResult,
  type ConfigValue,
  type ConfigValueKind,
  type MergeResult,
  parse_path,
}
