///|
fn wants_json_output(args : Array[String]) -> Bool {
  for index in 0..<args.length() {
    if args.get(index) == Some("--format") &&
      args.get(index + 1) == Some("json") {
      return true
    }
  }
  false
}

///|
fn main {
  let args = @env.args()
  match @cli.run(args) {
    Ok(output) => println(output)
    Err(message) => {
      if wants_json_output(args) && message.has_prefix("{") {
        println(message)
      } else {
        println("error: " + message)
      }
      @sys.exit(1)
    }
  }
}
