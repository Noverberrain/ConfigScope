// The root package is a small facade over ConfigScope's public packages.

///|
pub using @core {
  type ConfigPath,
  type ConfigPathError,
  type ConfigConflict,
  type ConfigValue,
  type ConfigValueKind,
  type MergeResult,
  parse_path,
}
