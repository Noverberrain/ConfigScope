///|
/// Print a short command usage message.
fn print_usage() -> Unit {
  println("Usage: configscope get <config.json> <path>")
}

///|
/// Query one configuration path from a JSON file.
fn run_get(file_path : String, path_text : String) -> Unit raise {
  let source = @fs.read_file_to_string(file_path)
  let value = @configscope.ConfigValue::parse_json(source)
  let path = @configscope.parse_path(path_text).unwrap()
  match value.get(path) {
    Some(result) => println(result.to_json_string())
    None => {
      println("configuration path '{path_text}' was not found")
      panic()
    }
  }
}

///|
fn main raise {
  let args = @env.args()
  if args.length() == 4 && args.get(1) == Some("get") {
    run_get(args.get(2).unwrap(), args.get(3).unwrap())
  } else {
    print_usage()
  }
}
