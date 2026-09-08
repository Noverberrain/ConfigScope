///|
/// A diagnostic view of one merged configuration field.
///
/// The explanation combines the final value with the layer that supplied it.
pub struct ConfigExplanation {
  path : ConfigPath
  value : ConfigValue
  source : String
} derive(Eq, Debug)

///|
/// Return the explained configuration path.
pub fn ConfigExplanation::path(self : ConfigExplanation) -> ConfigPath {
  self.path
}

///|
/// Return the final value found at the explained path.
pub fn ConfigExplanation::value(self : ConfigExplanation) -> ConfigValue {
  self.value
}

///|
/// Return the kind of the final value found at the explained path.
pub fn ConfigExplanation::kind(self : ConfigExplanation) -> ConfigValueKind {
  self.value.kind()
}

///|
/// Return the name of the layer that supplied the final value.
pub fn ConfigExplanation::source(self : ConfigExplanation) -> String {
  self.source
}

///|
/// Explain one final configuration field, or return `None` when the path is
/// missing from the merged value or has no tracked source.
pub fn LayeredMergeResult::explain(
  self : LayeredMergeResult,
  path : ConfigPath,
) -> ConfigExplanation? {
  let value = self.value.get(path)
  let source = self.source(path)
  match (value, source) {
    (Some(value), Some(source)) => Some({ path, value, source })
    _ => None
  }
}
