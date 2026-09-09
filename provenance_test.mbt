// Black-box tests for the ConfigScope public facade.

///|
test "layered merge tracks the source of final fields" {
  let defaults = @configscope.ConfigLayer::new(
    "defaults",
    @configscope.ConfigValue::object(
      Map([
        (
          "server",
          @configscope.ConfigValue::object(
            Map([
              ("host", @configscope.ConfigValue::string("127.0.0.1")),
              ("port", @configscope.ConfigValue::number(80.0)),
            ]),
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
  assert_eq(
    result.source(@configscope.parse_path("server").unwrap()).unwrap(),
    "production",
  )
  assert_eq(
    result.source(@configscope.parse_path("server.host").unwrap()).unwrap(),
    "defaults",
  )
  assert_eq(
    result.source(@configscope.parse_path("server.port").unwrap()).unwrap(),
    "production",
  )
  assert_eq(result.source_count(), 3)
}

///|
test "later scalar replacement removes stale descendant provenance" {
  let defaults = @configscope.ConfigLayer::new(
    "defaults",
    @configscope.ConfigValue::object(
      Map([
        (
          "feature",
          @configscope.ConfigValue::object(
            Map([("enabled", @configscope.ConfigValue::boolean(true))]),
          ),
        ),
      ]),
    ),
  )
  let production = @configscope.ConfigLayer::new(
    "production",
    @configscope.ConfigValue::object(
      Map([("feature", @configscope.ConfigValue::string("disabled"))]),
    ),
  )
  let result = @configscope.LayeredConfig::new([defaults, production])
    .merge_with_provenance()
    .unwrap()
  assert_eq(
    result.source(@configscope.parse_path("feature").unwrap()).unwrap(),
    "production",
  )
  assert_true(
    result.source(@configscope.parse_path("feature.enabled").unwrap()) is None,
  )
  assert_eq(result.source_count(), 1)
}

///|
test "provenance merge keeps conflict reports and latest source" {
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
  let result = @configscope.LayeredConfig::new([defaults, production])
    .merge_with_provenance()
    .unwrap()
  assert_eq(result.conflict_count(), 1)
  assert_eq(
    result.source(@configscope.parse_path("logging").unwrap()).unwrap(),
    "production",
  )
  assert_eq(
    result.source(@configscope.parse_path("logging.format").unwrap()).unwrap(),
    "production",
  )
}

///|
test "empty layered provenance merge has no result" {
  assert_true(
    @configscope.LayeredConfig::empty().merge_with_provenance() is None,
  )
}
