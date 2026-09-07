///|
/// The JSON-compatible kinds represented by a configuration value.
pub enum ConfigValueKind {
  Null
  Boolean
  Number
  String
  Array
  Object
} derive(Eq, Debug)

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
