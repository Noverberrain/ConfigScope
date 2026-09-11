///|
/// Read and merge JSON configuration files from first to last.
fn run_merge(args : Array[String]) -> Result[String, String] {
  let layers : Array[@configscope.ConfigLayer] = []
  for index in 2..<args.length() {
    let file_path = args.get(index).unwrap()
    let value = match read_config(file_path) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    layers.push(@configscope.ConfigLayer::new(file_path, value))
  }
  match @configscope.LayeredConfig::new(layers).merge() {
    Some(value) => Ok(value.to_json_string())
    None => Err("merge requires at least two JSON files")
  }
}
