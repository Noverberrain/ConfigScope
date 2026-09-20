///|
/// Return the command usage message.
pub fn usage() -> String {
  "Usage:\n  configscope compat <before.json> <after.json> [--fail-on breaking|behavioral|any] [--format text|json]\n  configscope compat-matrix <candidate.json> <baseline.json>... [--fail-on breaking|behavioral|any] [--format text|json]\n  configscope contract-init <candidate.json> <baseline.json>... [--fail-on breaking|behavioral|any] [--ignore-path path]... [--output contract.json]\n  configscope contract-check <contract.json> [--format text|json]"
}

///|
/// Read a JSON configuration file.
fn read_config(file_path : String) -> Result[@configscope.ConfigValue, String] {
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
  Ok(value)
}

///|
/// Run the CLI arguments and return either output or a user-facing error.
pub fn run(args : Array[String]) -> Result[String, String] {
  match args.get(1) {
    Some("compat") =>
      if args.length() >= 4 {
        run_compat(args)
      } else {
        Err(usage())
      }
    Some("compat-matrix") =>
      if args.length() >= 3 {
        run_compatibility_matrix(args)
      } else {
        Err(usage())
      }
    Some("contract-check") =>
      if args.length() == 3 || args.length() == 5 {
        run_contract_check(args)
      } else {
        Err(usage())
      }
    Some("contract-init") =>
      if args.length() >= 4 {
        run_contract_init(args)
      } else {
        Err(usage())
      }
    Some(_) => Err(usage())
    None => Err(usage())
  }
}
