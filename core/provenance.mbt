///|
/// The merged configuration together with the source of each final field.
pub struct LayeredMergeResult {
  value : ConfigValue
  conflicts : Array[ConfigConflict]
  sources : Map[String, String]
} derive(Eq, Debug)

///|
/// Return the merged configuration value.
pub fn LayeredMergeResult::value(self : LayeredMergeResult) -> ConfigValue {
  self.value
}

///|
/// Return the number of structural conflicts found during the merge.
pub fn LayeredMergeResult::conflict_count(self : LayeredMergeResult) -> Int {
  self.conflicts.length()
}

///|
/// Return one structural conflict, or `None` when the index is out of bounds.
pub fn LayeredMergeResult::conflict(
  self : LayeredMergeResult,
  index : Int,
) -> ConfigConflict? {
  self.conflicts.get(index)
}

///|
/// Return the name of the layer that supplied the final value at a path.
pub fn LayeredMergeResult::source(
  self : LayeredMergeResult,
  path : ConfigPath,
) -> String? {
  self.sources.get(path.to_string())
}

///|
/// Return the number of tracked configuration paths.
pub fn LayeredMergeResult::source_count(self : LayeredMergeResult) -> Int {
  self.sources.length()
}

///|
/// Record a layer as the source for a value and all of its descendants.
fn record_origins(
  value : Json,
  segments : Array[String],
  source : String,
  origins : Map[String, String],
) -> Unit {
  if segments.length() > 0 {
    origins[segments.join(".")] = source
  }
  match value {
    Object(fields) =>
      fields.each((key, child) => {
        let next_segments = segments.copy()
        next_segments.push(key)
        record_origins(child, next_segments, source, origins)
      })
    _ => ()
  }
}

///|
/// Remove all tracked paths that belong to an earlier value subtree.
fn remove_origins(
  value : Json,
  segments : Array[String],
  origins : Map[String, String],
) -> Unit {
  if segments.length() > 0 {
    origins.remove(segments.join("."))
  }
  match value {
    Object(fields) =>
      fields.each((key, child) => {
        let next_segments = segments.copy()
        next_segments.push(key)
        remove_origins(child, next_segments, origins)
      })
    _ => ()
  }
}

///|
/// Recursively merge values while updating field provenance.
fn deep_merge_with_provenance_raw(
  base : Json,
  later : Json,
  segments : Array[String],
  source : String,
  origins : Map[String, String],
  conflicts : Array[ConfigConflict],
) -> Json {
  match (base, later) {
    (Object(base_fields), Object(later_fields)) => {
      let merged_fields : Map[String, Json] = Map([])
      base_fields.each((key, value) => merged_fields[key] = value)
      if segments.length() > 0 {
        origins[segments.join(".")] = source
      }
      later_fields.each((key, value) => {
        let next_segments = segments.copy()
        next_segments.push(key)
        match base_fields.get(key) {
          Some(base_value) =>
            merged_fields[key] = deep_merge_with_provenance_raw(
              base_value, value, next_segments, source, origins, conflicts,
            )
          None => {
            merged_fields[key] = value
            record_origins(value, next_segments, source, origins)
          }
        }
      })
      Json::object(merged_fields)
    }
    (base_value, later_value) => {
      if (base_value is Object(_)) != (later_value is Object(_)) {
        conflicts.push({
          path: config_path_from_segments(segments),
          earlier_kind: ConfigValueKind::from_json(base_value),
          later_kind: ConfigValueKind::from_json(later_value),
        })
      }
      remove_origins(base_value, segments, origins)
      record_origins(later_value, segments, source, origins)
      later_value
    }
  }
}

///|
/// Merge all layers while retaining the source of each final configuration path.
///
/// An empty configuration has no value to merge and returns `None`.
pub fn LayeredConfig::merge_with_provenance(
  self : LayeredConfig,
) -> LayeredMergeResult? {
  let first = self.layers.get(0)
  match first {
    None => None
    Some(first_layer) => {
      let mut value = first_layer.value()
      let origins : Map[String, String] = Map([])
      record_origins(value.raw, [], first_layer.name(), origins)
      let conflicts : Array[ConfigConflict] = []
      let mut index = 1
      while index < self.layers.length() {
        let layer = self.layers.get(index).unwrap()
        let later = layer.value()
        value = {
          raw: deep_merge_with_provenance_raw(
            value.raw,
            later.raw,
            [],
            layer.name(),
            origins,
            conflicts,
          ),
        }
        index = index + 1
      }
      Some({ value, conflicts, sources: origins })
    }
  }
}
