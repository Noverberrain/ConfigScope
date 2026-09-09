///|
/// The JSON-compatible kinds represented by a configuration value.
pub(all) enum ConfigValueKind {
  Null
  Boolean
  Number
  String
  Array
  Object
} derive(Eq, Debug)

///|
/// A path at which recursive merge encountered incompatible structures.
pub struct ConfigConflict {
  path : ConfigPath
  earlier_kind : ConfigValueKind
  later_kind : ConfigValueKind
} derive(Eq, Debug)

///|
/// The merged value and structural conflicts found while producing it.
pub struct MergeResult {
  value : ConfigValue
  conflicts : Array[ConfigConflict]
} derive(Eq, Debug)

///|
/// Return the path where this conflict occurred.
pub fn ConfigConflict::path(self : ConfigConflict) -> ConfigPath {
  self.path
}

///|
/// Return the kind supplied by the earlier configuration.
pub fn ConfigConflict::earlier_kind(self : ConfigConflict) -> ConfigValueKind {
  self.earlier_kind
}

///|
/// Return the kind supplied by the later configuration.
pub fn ConfigConflict::later_kind(self : ConfigConflict) -> ConfigValueKind {
  self.later_kind
}

///|
/// Return the value produced by the reported merge.
pub fn MergeResult::value(self : MergeResult) -> ConfigValue {
  self.value
}

///|
/// Return the number of structural conflicts found by the merge.
pub fn MergeResult::conflict_count(self : MergeResult) -> Int {
  self.conflicts.length()
}

///|
/// Return one structural conflict, or `None` when the index is out of bounds.
pub fn MergeResult::conflict(
  self : MergeResult,
  index : Int,
) -> ConfigConflict? {
  self.conflicts.get(index)
}

///|
/// A JSON-compatible value used by ConfigScope's merge and analysis engine.
///
/// The underlying representation is intentionally private. This keeps later
/// merge and provenance work independent from the concrete JSON container.
pub struct ConfigValue {
  raw : Json
} derive(Eq, Debug)

///|
/// Construct a null configuration value.
pub fn ConfigValue::null() -> ConfigValue {
  { raw: Json::null() }
}

///|
/// Construct a boolean configuration value.
pub fn ConfigValue::boolean(value : Bool) -> ConfigValue {
  { raw: Json::boolean(value) }
}

///|
/// Construct a numeric configuration value.
pub fn ConfigValue::number(value : Double) -> ConfigValue {
  { raw: Json::number(value) }
}

///|
/// Construct a string configuration value.
pub fn ConfigValue::string(value : String) -> ConfigValue {
  { raw: Json::string(value) }
}

///|
/// Render this configuration value as compact JSON text.
pub fn ConfigValue::to_json_string(self : ConfigValue) -> String {
  self.raw.stringify()
}

///|
/// Construct an array configuration value.
///
/// The input array is copied into the private representation.
pub fn ConfigValue::array(values : Array[ConfigValue]) -> ConfigValue {
  { raw: Json::array(values.map(value => value.raw)) }
}

///|
/// Construct an object configuration value.
///
/// The input map is copied into the private representation, so later changes
/// to the caller's map do not change the constructed value.
pub fn ConfigValue::object(fields : Map[String, ConfigValue]) -> ConfigValue {
  let raw_fields : Map[String, Json] = Map([])
  fields.each((key, value) => raw_fields[key] = value.raw)
  { raw: Json::object(raw_fields) }
}

///|
/// Construct an empty object configuration value.
pub fn ConfigValue::empty_object() -> ConfigValue {
  { raw: Json::empty_object() }
}

///|
/// Return the kind of this value.
pub fn ConfigValue::kind(self : ConfigValue) -> ConfigValueKind {
  match self.raw {
    Null => Null
    True | False => Boolean
    Number(_) => Number
    String(_) => String
    Array(_) => Array
    Object(_) => Object
  }
}

///|
/// Return the boolean payload, or `None` for a different value kind.
pub fn ConfigValue::as_boolean(self : ConfigValue) -> Bool? {
  match self.raw {
    True => Some(true)
    False => Some(false)
    _ => None
  }
}

///|
/// Return the numeric payload, or `None` for a different value kind.
pub fn ConfigValue::as_number(self : ConfigValue) -> Double? {
  match self.raw {
    Number(value, ..) => Some(value)
    _ => None
  }
}

///|
/// Return the string payload, or `None` for a different value kind.
pub fn ConfigValue::as_string(self : ConfigValue) -> String? {
  match self.raw {
    String(value) => Some(value)
    _ => None
  }
}

///|
/// Return the number of elements for an array or fields for an object.
/// Scalar values return `None`.
pub fn ConfigValue::length(self : ConfigValue) -> Int? {
  match self.raw {
    Array(values) => Some(values.length())
    Object(fields) => Some(fields.length())
    _ => None
  }
}

///|
/// Read one array element, or `None` if this is not an array or the index is
/// outside its bounds.
pub fn ConfigValue::element(self : ConfigValue, index : Int) -> ConfigValue? {
  match self.raw {
    Array(values) => values.get(index).map(raw => { raw, })
    _ => None
  }
}

///|
/// Read one object field, or `None` if this is not an object or the key is
/// absent.
pub fn ConfigValue::field(self : ConfigValue, key : String) -> ConfigValue? {
  match self.raw {
    Object(fields) => fields.get(key).map(raw => { raw, })
    _ => None
  }
}

///|
/// Return whether an object contains a field with the given key.
pub fn ConfigValue::contains_field(self : ConfigValue, key : String) -> Bool {
  match self.raw {
    Object(fields) => fields.contains(key)
    _ => false
  }
}

///|
/// Classify a JSON value as a configuration value kind.
fn ConfigValueKind::from_json(value : Json) -> ConfigValueKind {
  match value {
    Null => Null
    True | False => Boolean
    Number(_) => Number
    String(_) => String
    Array(_) => Array
    Object(_) => Object
  }
}

///|
/// Return the stable lowercase name used in diagnostics and reports.
pub fn ConfigValueKind::to_string(self : ConfigValueKind) -> String {
  match self {
    Null => "null"
    Boolean => "boolean"
    Number => "number"
    String => "string"
    Array => "array"
    Object => "object"
  }
}

///|
/// Read a nested value using a dot-separated configuration path.
///
/// The lookup succeeds only when every path segment selects an object field.
/// Arrays are intentionally not indexed by this first path API.
pub fn ConfigValue::get(self : ConfigValue, path : ConfigPath) -> ConfigValue? {
  let mut current = self
  for segment in path.segments {
    match current.raw {
      Object(fields) =>
        match fields.get(segment) {
          Some(raw) => current = { raw, }
          None => return None
        }
      _ => return None
    }
  }
  Some(current)
}

///|
/// Merge an earlier configuration value with a later override.
///
/// Object fields are combined at the current level, and fields from the
/// override replace fields with the same key. Nested objects are replaced as
/// whole values; recursive merging will be added separately.
pub fn ConfigValue::merge(
  self : ConfigValue,
  later : ConfigValue,
) -> ConfigValue {
  match (self.raw, later.raw) {
    (Object(base_fields), Object(later_fields)) => {
      let merged_fields : Map[String, Json] = Map([])
      base_fields.each((key, value) => merged_fields[key] = value)
      later_fields.each((key, value) => merged_fields[key] = value)
      { raw: Json::object(merged_fields) }
    }
    (_, later_raw) => { raw: later_raw }
  }
}

///|
/// Recursively merge an earlier configuration value with a later override.
///
/// When both values at a field are objects, their fields are merged
/// recursively. Arrays and scalar values are replaced by the later value.
fn deep_merge_with_report_raw(
  base : Json,
  later : Json,
  segments : Array[String],
  conflicts : Array[ConfigConflict],
) -> Json {
  match (base, later) {
    (Object(base_fields), Object(later_fields)) => {
      let merged_fields : Map[String, Json] = Map([])
      base_fields.each((key, value) => merged_fields[key] = value)
      later_fields.each((key, value) => {
        let next_segments = segments.copy()
        next_segments.push(key)
        match base_fields.get(key) {
          Some(base_value) =>
            merged_fields[key] = deep_merge_with_report_raw(
              base_value, value, next_segments, conflicts,
            )
          None => merged_fields[key] = value
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
      later_value
    }
  }
}

///|
fn deep_merge_raw(base : Json, later : Json) -> Json {
  match (base, later) {
    (Object(base_fields), Object(later_fields)) => {
      let merged_fields : Map[String, Json] = Map([])
      base_fields.each((key, value) => merged_fields[key] = value)
      later_fields.each((key, value) => {
        match base_fields.get(key) {
          Some(base_value) =>
            merged_fields[key] = deep_merge_raw(base_value, value)
          None => merged_fields[key] = value
        }
      })
      Json::object(merged_fields)
    }
    (_, later_value) => later_value
  }
}

///|
/// Describe a recursive merge together with structural type conflicts.
pub fn ConfigValue::deep_merge_with_report(
  self : ConfigValue,
  later : ConfigValue,
) -> MergeResult {
  let conflicts : Array[ConfigConflict] = []
  let merged = deep_merge_with_report_raw(self.raw, later.raw, [], conflicts)
  { value: { raw: merged }, conflicts }
}

///|
/// Recursively merge two configuration values, with the later value winning.
///
/// Nested objects preserve fields from both inputs. A later scalar, array, or
/// type change replaces the earlier value at that field.
pub fn ConfigValue::deep_merge(
  self : ConfigValue,
  later : ConfigValue,
) -> ConfigValue {
  { raw: deep_merge_raw(self.raw, later.raw) }
}

///|
/// Parse a JSON text into a configuration value.
///
/// The parser accepts every JSON value, including a root scalar or array.
pub fn ConfigValue::parse_json(
  source : String,
) -> ConfigValue raise @json.ParseError {
  { raw: @json.parse(source) }
}
