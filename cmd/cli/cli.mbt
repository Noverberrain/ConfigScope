///|
/// Return the command usage message.
pub fn usage() -> String {
  "Usage:\n  configscope get <config.json> <path>\n  configscope audit <config.json> [--required <path>] [--type <path>:<kind>]"
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
  let value = match read_config(file_path) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match value.get(path) {
    Some(result) => Ok(result.to_json_string())
    None => Err("configuration path '\{path_text}' was not found")
  }
}

///|
/// Parse a value kind named on the command line.
fn parse_kind(
  kind_text : String,
) -> Result[@configscope.ConfigValueKind, String] {
  match kind_text {
    "null" => Ok(Null)
    "boolean" => Ok(Boolean)
    "number" => Ok(Number)
    "string" => Ok(String)
    "array" => Ok(Array)
    "object" => Ok(Object)
    _ =>
      Err(
        "unknown configuration kind '" +
        kind_text +
        "'; expected null, boolean, number, string, array, or object",
      )
  }
}

///|
/// Parse a required-path audit rule.
fn parse_required_rule(
  path_text : String,
) -> Result[@configscope.ConfigAuditRule, String] {
  match @configscope.parse_path(path_text) {
    Ok(path) => Ok(@configscope.ConfigAuditRule::required(path))
    Err(error) =>
      Err(
        "invalid configuration path '" + path_text + "': " + error.to_string(),
      )
  }
}

///|
/// Parse a path and kind pair such as `server.port:number`.
fn parse_type_rule(
  rule_text : String,
) -> Result[@configscope.ConfigAuditRule, String] {
  let parts = rule_text.split(":").to_array()
  if parts.length() != 2 {
    return Err("type rule must use <path>:<kind>")
  }
  let path_text = parts.get(0).unwrap().to_owned()
  let kind_text = parts.get(1).unwrap().to_owned()
  let path = match @configscope.parse_path(path_text) {
    Ok(path) => path
    Err(error) =>
      return Err(
        "invalid configuration path '" + path_text + "': " + error.to_string(),
      )
  }
  let kind = match parse_kind(kind_text) {
    Ok(kind) => kind
    Err(error) => return Err(error)
  }
  Ok(@configscope.ConfigAuditRule::type_is(path, kind))
}

///|
/// Parse repeated audit options after the configuration file path.
fn parse_audit_rules(
  args : Array[String],
  index : Int,
  rules : Array[@configscope.ConfigAuditRule],
) -> Result[Array[@configscope.ConfigAuditRule], String] {
  if index >= args.length() {
    if rules.length() == 0 {
      Err("audit requires at least one --required or --type rule")
    } else {
      Ok(rules)
    }
  } else {
    match args.get(index) {
      Some("--required") =>
        match args.get(index + 1) {
          Some(path_text) =>
            match parse_required_rule(path_text) {
              Ok(rule) => {
                rules.push(rule)
                parse_audit_rules(args, index + 2, rules)
              }
              Err(error) => Err(error)
            }
          None => Err("missing path after --required")
        }
      Some("--type") =>
        match args.get(index + 1) {
          Some(rule_text) =>
            match parse_type_rule(rule_text) {
              Ok(rule) => {
                rules.push(rule)
                parse_audit_rules(args, index + 2, rules)
              }
              Err(error) => Err(error)
            }
          None => Err("missing <path>:<kind> after --type")
        }
      Some(option) => Err("unknown audit option '" + option + "'")
      None => Err("invalid audit arguments")
    }
  }
}

///|
/// Audit a JSON configuration file using command-line rules.
fn run_audit(args : Array[String]) -> Result[String, String] {
  let rules = match parse_audit_rules(args, 3, []) {
    Ok(rules) => rules
    Err(error) => return Err(error)
  }
  let value = match read_config(args.get(2).unwrap()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let issues = value.audit(rules)
  if issues.length() == 0 {
    Ok("audit passed")
  } else {
    Err(issues.map(issue => issue.message()).join("\n"))
  }
}

///|
/// Run the CLI arguments and return either output or a user-facing error.
pub fn run(args : Array[String]) -> Result[String, String] {
  match args.get(1) {
    Some("get") =>
      if args.length() == 4 {
        run_get(args.get(2).unwrap(), args.get(3).unwrap())
      } else {
        Err(usage())
      }
    Some("audit") =>
      if args.length() >= 3 {
        run_audit(args)
      } else {
        Err(usage())
      }
    Some(_) => Err(usage())
    None => Err(usage())
  }
}
