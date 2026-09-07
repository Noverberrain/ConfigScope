// The root package is a small facade over ConfigScope's public packages.

///|
pub using @core {
  type ConfigPath,
  type ConfigPathError,
  type ConfigValue,
  type ConfigValueKind,
  parse_path,
}
