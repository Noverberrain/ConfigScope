///|
/// Replace selected configuration paths with a fixed redaction marker.
///
/// Redaction matches complete paths only. The input value is not modified.
pub fn ConfigValue::redact(
  self : ConfigValue,
  paths : Array[ConfigPath],
) -> ConfigValue {
  redact_raw(self.raw, [], paths)
}

///|
fn redact_raw(
  value : Json,
  segments : Array[String],
  paths : Array[ConfigPath],
) -> ConfigValue {
  let current_path = config_path_from_segments(segments)
  if paths.any(path => path == current_path) {
    return ConfigValue::string("[REDACTED]")
  }
  match value {
    Object(fields) => {
      let output : Map[String, Json] = Map([])
      fields.each((key, child) => {
        let next_segments = segments.copy()
        next_segments.push(key)
        output[key] = redact_raw(child, next_segments, paths).raw
      })
      { raw: Json::object(output) }
    }
    Array(values) => {
      let output = values.map(child => redact_raw(child, segments, paths).raw)
      { raw: Json::array(output) }
    }
    _ => { raw: value }
  }
}
