// Black-box tests for the ConfigScope public facade.

///|
test "layered merge explains a final field" {
  let defaults = @configscope.ConfigLayer::new(
    "defaults",
    @configscope.ConfigValue::object(
      Map([
        (
          "server",
          @configscope.ConfigValue::object(
            Map([("host", @configscope.ConfigValue::string("127.0.0.1"))]),
          ),
        ),
      ]),
    ),
  )
  let production = @configscope.ConfigLayer::new(
    "production",
    @configscope.ConfigValue::object(
      Map([
        (
          "server",
          @configscope.ConfigValue::object(
            Map([("port", @configscope.ConfigValue::number(8080.0))]),
          ),
        ),
      ]),
    ),
  )
  let path = @configscope.parse_path("server.port").unwrap()
  let explanation = @configscope.LayeredConfig::new([defaults, production])
    .merge_with_provenance()
    .unwrap()
    .explain(path)
    .unwrap()
  assert_eq(explanation.path().to_string(), "server.port")
  assert_eq(explanation.kind().to_string(), "number")
  assert_eq(explanation.value().as_number().unwrap(), 8080.0)
  assert_eq(explanation.source(), "production")
}

///|
test "explain preserves the source of an inherited nested field" {
  let defaults = @configscope.ConfigLayer::new(
    "defaults",
    @configscope.ConfigValue::object(
      Map([
        (
          "server",
          @configscope.ConfigValue::object(
            Map([("host", @configscope.ConfigValue::string("127.0.0.1"))]),
          ),
        ),
      ]),
    ),
  )
  let production = @configscope.ConfigLayer::new(
    "production",
    @configscope.ConfigValue::object(
      Map([
        (
          "server",
          @configscope.ConfigValue::object(
            Map([("port", @configscope.ConfigValue::number(8080.0))]),
          ),
        ),
      ]),
    ),
  )
  let result = @configscope.LayeredConfig::new([defaults, production])
    .merge_with_provenance()
    .unwrap()
  let explanation = result
    .explain(@configscope.parse_path("server.host").unwrap())
    .unwrap()
  assert_eq(explanation.value().as_string().unwrap(), "127.0.0.1")
  assert_eq(explanation.source(), "defaults")
}

///|
test "explain returns none for missing or untracked paths" {
  let result = @configscope.LayeredConfig::new([
      @configscope.ConfigLayer::new(
        "defaults",
        @configscope.ConfigValue::object(
          Map([("feature", @configscope.ConfigValue::string("enabled"))]),
        ),
      ),
    ])
    .merge_with_provenance()
    .unwrap()
  assert_true(
    result.explain(@configscope.parse_path("missing").unwrap()) is None,
  )
  assert_true(
    result.explain(@configscope.parse_path("feature.enabled").unwrap()) is None,
  )
}
