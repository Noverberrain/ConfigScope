///|
/// Return the command usage message.
pub fn usage() -> String {
  "Usage: configscope get <config.json> <path>"
}

///|
/// Query one configuration path from a JSON file.
fn run_get(file_path : String, path_text : String) -> Result[String, String] {
  let path = match @configscope.parse_path(path_text) {
    Ok(path) => path
    Err(path_error) =>
      return Err(
        "invalid configuration path '" +
        path_text +
        "': " +
        path_error.to_string(),
      )
  }
  if !@fs.path_exists(file_path) {
    return Err("file '\{file_path}' does not exist")
  }
  let source : Result[String, String] = Ok(@fs.read_file_to_string(file_path)) catch {
    _ => Err("cannot read file '\{file_path}'")
  }
  let source = match source {
    Ok(source) => source
    Err(error) => return Err(error)
  }
  let value : Result[@configscope.ConfigValue, String] = Ok(
    @configscope.ConfigValue::parse_json(source),
  ) catch {
    _ => Err("invalid JSON in '\{file_path}'")
  }
  let value = match value {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match value.get(path) {
    Some(result) => Ok(result.to_json_string())
    None => Err("configuration path '\{path_text}' was not found")
  }
}

///|
/// Run the CLI arguments and return either output or a user-facing error.
pub fn run(args : Array[String]) -> Result[String, String] {
  if args.length() != 4 || args.get(1) != Some("get") {
    Err(usage())
  } else {
    run_get(args.get(2).unwrap(), args.get(3).unwrap())
  }
}
