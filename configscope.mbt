// The root package is a small facade over ConfigScope's public packages.

///|
pub using @core {
  type ConfigPath,
  type ConfigPathError,
  type ConfigCompatibilityChange,
  type ConfigCompatibilityImpact,
  type ConfigCompatibilityBaseline,
  type ConfigCompatibilityContract,
  type ConfigCompatibilityMatrixEntry,
  type ConfigCompatibilityMatrixReport,
  type ConfigCompatibilityPolicy,
  type ConfigCompatibilityReport,
  type ConfigDiff,
  type ConfigDiffKind,
  type ConfigValue,
  type ConfigValueKind,
  parse_path,
}
