// Black-box tests for the ConfigScope public facade.

///|
test "configuration layers keep a source name and value" {
  let config = @configscope.ConfigValue::object(
    Map([("port", @configscope.ConfigValue::number(8080.0))]),
  )
  let layer = @configscope.ConfigLayer::new("production", config)
  assert_eq(layer.name(), "production")
  assert_eq(layer.value(), config)
  assert_eq(
    layer
    .value()
    .get(@configscope.parse_path("port").unwrap())
    .unwrap()
    .as_number()
    .unwrap(),
    8080.0,
  )
}

///|
test "configuration layers distinguish sources with equal values" {
  let config = @configscope.ConfigValue::string("same")
  let defaults = @configscope.ConfigLayer::new("defaults", config)
  let workstation = @configscope.ConfigLayer::new("local", config)
  assert_eq(defaults.value(), workstation.value())
  assert_true(defaults.name() != workstation.name())
  assert_true(defaults != workstation)
}

///|
test "layered configurations merge layers in order" {
  let defaults = @configscope.ConfigLayer::new(
    "defaults",
    @configscope.ConfigValue::object(
      Map([
        ("port", @configscope.ConfigValue::number(80.0)),
        ("host", @configscope.ConfigValue::string("127.0.0.1")),
      ]),
    ),
  )
  let production = @configscope.ConfigLayer::new(
    "production",
    @configscope.ConfigValue::object(
      Map([
        ("port", @configscope.ConfigValue::number(8080.0)),
        ("tls", @configscope.ConfigValue::boolean(true)),
      ]),
    ),
  )
  let layered = @configscope.LayeredConfig::new([defaults, production])
  assert_eq(layered.length(), 2)
  assert_eq(layered.layer(0).unwrap().name(), "defaults")
  assert_eq(layered.layer(1).unwrap().name(), "production")
  let merged = layered.merge().unwrap()
  assert_eq(merged.field("port").unwrap().as_number().unwrap(), 8080.0)
  assert_eq(merged.field("host").unwrap().as_string().unwrap(), "127.0.0.1")
  assert_true(merged.field("tls").unwrap().as_boolean().unwrap())
}

///|
test "layered configuration reports conflicts from each later layer" {
  let defaults = @configscope.ConfigLayer::new(
    "defaults",
    @configscope.ConfigValue::object(
      Map([("logging", @configscope.ConfigValue::string("compact"))]),
    ),
  )
  let production = @configscope.ConfigLayer::new(
    "production",
    @configscope.ConfigValue::object(
      Map([
        (
          "logging",
          @configscope.ConfigValue::object(
            Map([("format", @configscope.ConfigValue::string("json"))]),
          ),
        ),
      ]),
    ),
  )
  let command_line = @configscope.ConfigLayer::new(
    "command-line",
    @configscope.ConfigValue::object(
      Map([("logging", @configscope.ConfigValue::string("verbose"))]),
    ),
  )
  let result = @configscope.LayeredConfig::new([
      defaults, production, command_line,
    ])
    .merge_with_report()
    .unwrap()
  assert_eq(result.conflict_count(), 2)
  assert_eq(result.conflict(0).unwrap().path().to_string(), "logging")
  assert_eq(result.conflict(1).unwrap().path().to_string(), "logging")
  assert_eq(
    result.value().field("logging").unwrap().as_string().unwrap(),
    "verbose",
  )
}

///|
test "empty layered configuration has no merged value" {
  let layered = @configscope.LayeredConfig::empty()
  assert_eq(layered.length(), 0)
  assert_true(layered.layer(0) is None)
  assert_true(layered.merge() is None)
  assert_true(layered.merge_with_report() is None)
}

///|
test "layered configuration copies the input layer list" {
  let defaults = @configscope.ConfigLayer::new(
    "defaults",
    @configscope.ConfigValue::string("base"),
  )
  let layers = [defaults]
  let layered = @configscope.LayeredConfig::new(layers)
  layers.push(
    @configscope.ConfigLayer::new(
      "production",
      @configscope.ConfigValue::string("prod"),
    ),
  )
  assert_eq(layered.length(), 1)
}
