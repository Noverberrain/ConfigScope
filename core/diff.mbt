///|
/// Describes how one configuration path differs between two values.
pub(all) enum ConfigDiffKind {
  Added
  Removed
  Changed
  TypeChanged
} derive(Eq, Debug)

///|
/// A single difference between an earlier and a later configuration value.
pub struct ConfigDiff {
  path : ConfigPath
  kind : ConfigDiffKind
  before : ConfigValue?
  after : ConfigValue?
} derive(Eq, Debug)

///|
/// Return the path at which this difference occurred.
pub fn ConfigDiff::path(self : ConfigDiff) -> ConfigPath {
  self.path
}

///|
/// Return the category of this difference.
pub fn ConfigDiff::kind(self : ConfigDiff) -> ConfigDiffKind {
  self.kind
}

///|
/// Return the earlier value, or `None` when the path was added.
pub fn ConfigDiff::before(self : ConfigDiff) -> ConfigValue? {
  self.before
}

///|
/// Return the later value, or `None` when the path was removed.
pub fn ConfigDiff::after(self : ConfigDiff) -> ConfigValue? {
  self.after
}

///|
/// Return a stable lowercase name for this difference category.
pub fn ConfigDiffKind::to_string(self : ConfigDiffKind) -> String {
  match self {
    Added => "added"
    Removed => "removed"
    Changed => "changed"
    TypeChanged => "type_changed"
  }
}

///|
/// Append one difference to a collection.
fn push_diff(
  differences : Array[ConfigDiff],
  segments : Array[String],
  kind : ConfigDiffKind,
  before : ConfigValue?,
  after : ConfigValue?,
) -> Unit {
  differences.push({
    path: config_path_from_segments(segments),
    kind,
    before,
    after,
  })
}

///|
/// Recursively compare two JSON values and collect their differences.
fn diff_raw(
  before : Json,
  after : Json,
  segments : Array[String],
  differences : Array[ConfigDiff],
) -> Unit {
  if before == after {
    return
  }
  match (before, after) {
    (Object(before_fields), Object(after_fields)) => {
      let keys = before_fields.keys().to_array()
      after_fields
      .keys()
      .each(key => if !before_fields.contains(key) { keys.push(key) })
      keys.sort_by((left, right) => left.lexical_compare(right))
      for key in keys {
        let next_segments = segments.copy()
        next_segments.push(key)
        match (before_fields.get(key), after_fields.get(key)) {
          (Some(before_value), Some(after_value)) =>
            diff_raw(before_value, after_value, next_segments, differences)
          (Some(before_value), None) =>
            push_diff(
              differences,
              next_segments,
              Removed,
              Some({ raw: before_value }),
              None,
            )
          (None, Some(after_value)) =>
            push_diff(
              differences,
              next_segments,
              Added,
              None,
              Some({ raw: after_value }),
            )
          (None, None) => ()
        }
      }
    }
    (before_value, after_value) => {
      let before_config = { raw: before_value }
      let after_config = { raw: after_value }
      let kind = if ConfigValueKind::from_json(before_value) ==
        ConfigValueKind::from_json(after_value) {
        Changed
      } else {
        TypeChanged
      }
      push_diff(
        differences,
        segments,
        kind,
        Some(before_config),
        Some(after_config),
      )
    }
  }
}

///|
/// Compare this configuration with a later value.
///
/// Object fields are compared recursively. Added and removed object fields are
/// reported as one difference for the whole field. Arrays are compared as whole
/// values in this first diff implementation. Results are ordered by path.
pub fn ConfigValue::diff(
  self : ConfigValue,
  later : ConfigValue,
) -> Array[ConfigDiff] {
  let differences : Array[ConfigDiff] = []
  diff_raw(self.raw, later.raw, [], differences)
  differences.sort_by((left, right) => {
    left.path.to_string().lexical_compare(right.path.to_string())
  })
  differences
}
