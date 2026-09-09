// Black-box tests for the ConfigScope public facade.

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
