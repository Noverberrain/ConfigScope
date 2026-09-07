///|
/// A dot-separated path that identifies one value in a configuration tree.
///
/// The first version intentionally supports only simple paths such as
/// `server.port`. Escaping dots inside key names will be added separately if
/// the project later needs it.
pub struct ConfigPath {
  segments : Array[String]
} derive(Eq, Debug)

///|
/// Describes why a textual configuration path could not be parsed.
pub(all) enum ConfigPathError {
  EmptyPath
  EmptySegment(Int)
} derive(Eq, Debug)

///|
/// Parse a simple dot-separated configuration path.
///
/// Empty paths and empty segments are rejected, so `.server`, `server..port`,
/// and `server.` are invalid.
pub fn parse_path(source : String) -> Result[ConfigPath, ConfigPathError] {
  if source.is_empty() {
    return Err(EmptyPath)
  }
  let segments = Array::new()
  for index, segment in source.split(".") {
    if segment.is_empty() {
      return Err(EmptySegment(index))
    }
    segments.push(String::from_iter(segment.iter()))
  }
  Ok({ segments, })
}

///|
/// Return the number of segments in the path.
pub fn ConfigPath::length(self : ConfigPath) -> Int {
  self.segments.length()
}

///|
/// Return one segment, or `None` when the index is outside the path.
pub fn ConfigPath::segment(self : ConfigPath, index : Int) -> String? {
  self.segments.get(index)
}

///|
/// Convert the path back to its canonical dot-separated representation.
pub fn ConfigPath::to_string(self : ConfigPath) -> String {
  self.segments.join(".")
}

///|
/// Render a concise diagnostic for an invalid path.
pub fn ConfigPathError::to_string(self : ConfigPathError) -> String {
  match self {
    EmptyPath => "configuration path must not be empty"
    EmptySegment(index) =>
      "configuration path segment \{index} must not be empty"
  }
}
