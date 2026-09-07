// Black-box tests for the public ConfigScope facade.

///|
test "parse a nested configuration path" {
  let path = @configscope.parse_path("server.http.port").unwrap()
  inspect(path.length(), content="3")
  assert_eq(path.segment(0).unwrap(), "server")
  assert_eq(path.segment(1).unwrap(), "http")
  assert_eq(path.segment(2).unwrap(), "port")
  assert_true(path.segment(3) is None)
  inspect(path.to_string(), content="server.http.port")
}

///|
test "parse a single path segment" {
  let path = @configscope.parse_path("debug").unwrap()
  inspect(path.length(), content="1")
  inspect(path.to_string(), content="debug")
}

///|
test "reject empty paths and empty segments" {
  inspect(
    @configscope.parse_path("").unwrap_err().to_string(),
    content="configuration path must not be empty",
  )
  inspect(
    @configscope.parse_path(".server").unwrap_err().to_string(),
    content="configuration path segment 0 must not be empty",
  )
  inspect(
    @configscope.parse_path("server..port").unwrap_err().to_string(),
    content="configuration path segment 1 must not be empty",
  )
  inspect(
    @configscope.parse_path("server.").unwrap_err().to_string(),
    content="configuration path segment 1 must not be empty",
  )
}

///|
test "construct and inspect scalar configuration values" {
  let null_value = @configscope.ConfigValue::null()
  assert_eq(null_value.kind().to_string(), "null")
  assert_true(null_value.as_boolean() is None)

  let enabled = @configscope.ConfigValue::boolean(true)
  assert_eq(enabled.kind().to_string(), "boolean")
  assert_eq(enabled.as_boolean().unwrap(), true)

  let timeout = @configscope.ConfigValue::number(1500.0)
  assert_eq(timeout.kind().to_string(), "number")
  assert_eq(timeout.as_number().unwrap(), 1500.0)

  let environment = @configscope.ConfigValue::string("production")
  assert_eq(environment.kind().to_string(), "string")
  assert_eq(environment.as_string().unwrap(), "production")
}

///|
test "construct and inspect array configuration values" {
  let ports = @configscope.ConfigValue::array([
    @configscope.ConfigValue::number(8080.0),
    @configscope.ConfigValue::number(8081.0),
  ])
  assert_eq(ports.kind().to_string(), "array")
  assert_eq(ports.length().unwrap(), 2)
  assert_eq(ports.element(0).unwrap().as_number().unwrap(), 8080.0)
  assert_eq(ports.element(1).unwrap().as_number().unwrap(), 8081.0)
  assert_true(ports.element(2) is None)
  assert_true(ports.field("port") is None)
}

///|
test "construct and inspect object configuration values" {
  let fields : Map[String, @configscope.ConfigValue] = Map([
    ("host", @configscope.ConfigValue::string("127.0.0.1")),
    ("port", @configscope.ConfigValue::number(8080.0)),
  ])
  let server = @configscope.ConfigValue::object(fields)
  assert_eq(server.kind().to_string(), "object")
  assert_eq(server.length().unwrap(), 2)
  assert_true(server.contains_field("host"))
  assert_false(server.contains_field("debug"))
  assert_eq(server.field("host").unwrap().as_string().unwrap(), "127.0.0.1")
  assert_eq(server.field("port").unwrap().as_number().unwrap(), 8080.0)
  assert_true(server.field("debug") is None)
  assert_true(server.element(0) is None)
}

///|
test "object construction isolates the input map" {
  let fields : Map[String, @configscope.ConfigValue] = Map([
    ("debug", @configscope.ConfigValue::boolean(false)),
  ])
  let config = @configscope.ConfigValue::object(fields)
  fields["debug"] = @configscope.ConfigValue::boolean(true)
  assert_eq(config.field("debug").unwrap().as_boolean().unwrap(), false)
}

///|
test "lookup nested values by configuration path" {
  let server : Map[String, @configscope.ConfigValue] = Map([
    (
      "http",
      @configscope.ConfigValue::object(
        Map([
          ("port", @configscope.ConfigValue::number(8080.0)),
          ("enabled", @configscope.ConfigValue::boolean(true)),
        ]),
      ),
    ),
  ])
  let config = @configscope.ConfigValue::object(
    Map([("server", @configscope.ConfigValue::object(server))]),
  )
  let port_path = @configscope.parse_path("server.http.port").unwrap()
  let enabled_path = @configscope.parse_path("server.http.enabled").unwrap()
  assert_eq(config.get(port_path).unwrap().as_number().unwrap(), 8080.0)
  assert_eq(config.get(enabled_path).unwrap().as_boolean().unwrap(), true)
}

///|
test "lookup returns none for missing or non-object paths" {
  let config = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([("port", @configscope.ConfigValue::number(8080.0))]),
        ),
      ),
      ("name", @configscope.ConfigValue::string("configscope")),
      (
        "ports",
        @configscope.ConfigValue::array([
          @configscope.ConfigValue::number(8080.0),
        ]),
      ),
    ]),
  )
  assert_true(
    config.get(@configscope.parse_path("server.http.port").unwrap()) is None,
  )
  assert_true(
    config.get(@configscope.parse_path("server.port_number").unwrap()) is None,
  )
  assert_true(
    config.get(@configscope.parse_path("name.value").unwrap()) is None,
  )
  assert_true(config.get(@configscope.parse_path("ports.0").unwrap()) is None)
}

///|
test "lookup can return an object or a scalar at any path depth" {
  let config = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([
            (
              "http",
              @configscope.ConfigValue::object(
                Map([("port", @configscope.ConfigValue::number(8080.0))]),
              ),
            ),
          ]),
        ),
      ),
    ]),
  )
  let server = config.get(@configscope.parse_path("server").unwrap()).unwrap()
  assert_eq(server.kind().to_string(), "object")
  let http = config
    .get(@configscope.parse_path("server.http").unwrap())
    .unwrap()
  assert_eq(http.kind().to_string(), "object")
  let port = config
    .get(@configscope.parse_path("server.http.port").unwrap())
    .unwrap()
  assert_eq(port.kind().to_string(), "number")
}
