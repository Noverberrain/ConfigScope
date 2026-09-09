///|
fn main {
  match @cli.run(@env.args()) {
    Ok(output) => println(output)
    Err(message) => {
      println("error: " + message)
      @sys.exit(1)
    }
  }
}
