///|
priv struct ServiceSettings {
  port : Double
  logging_level : String
  workers : Double
}

///|
/// This sample consumer reads its own configuration directly. It deliberately
/// does not import ConfigScope or use its rule interpreter.
fn decode_settings(value : Json) -> Result[ServiceSettings, String] {
  let root = match value {
    Object(root) => root
    _ => return Err("configuration must be an object")
  }
  let server = match root.get("server") {
    Some(Object(server)) => server
    _ => return Err("server must be present and an object")
  }
  let port = match server.get("port") {
    Some(Number(port, ..)) if port == 8080.0 || port == 9090.0 => port
    _ => return Err("server.port must be an accepted numeric port")
  }
  let logging_level = match root.get("logging") {
    None => "info"
    Some(Object(logging)) =>
      match logging.get("level") {
        None => "info"
        Some(String(level)) if level == "info" || level == "warn" => level
        _ => return Err("logging.level must be an accepted string")
      }
    _ => return Err("logging must be an object when present")
  }
  let workers = match server.get("workers") {
    None => 4.0
    Some(Number(workers, ..)) if workers >= 1.0 &&
      workers <= 64.0 &&
      workers.floor() == workers => workers
    _ => return Err("server.workers must be an integer from 1 to 64")
  }
  Ok({ port, logging_level, workers, })
}

///|
fn load_settings(args : Array[String]) -> Result[ServiceSettings, String] {
  let file = match args.get(1) {
    Some(file) if args.length() == 2 => file
    _ => return Err("usage: service_consumer SNAPSHOT_JSON")
  }
  let source : Result[String, String] = Ok(@fs.read_file_to_string(file)) catch {
    _ => Err("cannot read snapshot")
  }
  let source = match source {
    Ok(source) => source
    Err(error) => return Err(error)
  }
  let value : Result[Json, String] = Ok(@json.parse(source)) catch {
    _ => Err("invalid JSON snapshot")
  }
  match value {
    Ok(value) => decode_settings(value)
    Err(error) => Err(error)
  }
}

///|
fn main {
  match load_settings(@env.args()) {
    Ok(settings) =>
      println(
        "settings accepted: port=\{settings.port} log=\{settings.logging_level} workers=\{settings.workers}",
      )
    Err(error) => {
      println("consumer rejected: " + error)
      @sys.exit(1)
    }
  }
}
