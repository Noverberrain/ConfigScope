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

///|
test "merge combines object fields with later values winning" {
  let defaults = @configscope.ConfigValue::object(
    Map([
      ("host", @configscope.ConfigValue::string("127.0.0.1")),
      ("port", @configscope.ConfigValue::number(80.0)),
      ("debug", @configscope.ConfigValue::boolean(false)),
    ]),
  )
  let environment = @configscope.ConfigValue::object(
    Map([
      ("port", @configscope.ConfigValue::number(8080.0)),
      ("debug", @configscope.ConfigValue::boolean(true)),
    ]),
  )
  let merged = defaults.merge(environment)
  assert_eq(merged.field("host").unwrap().as_string().unwrap(), "127.0.0.1")
  assert_eq(merged.field("port").unwrap().as_number().unwrap(), 8080.0)
  assert_eq(merged.field("debug").unwrap().as_boolean().unwrap(), true)
  assert_eq(merged.length().unwrap(), 3)
}

///|
test "merge replaces nested objects as a shallow operation" {
  let defaults = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([
            ("host", @configscope.ConfigValue::string("localhost")),
            ("port", @configscope.ConfigValue::number(80.0)),
          ]),
        ),
      ),
    ]),
  )
  let environment = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([("port", @configscope.ConfigValue::number(8080.0))]),
        ),
      ),
    ]),
  )
  let merged = defaults.merge(environment)
  let server = merged.field("server").unwrap()
  assert_eq(server.field("port").unwrap().as_number().unwrap(), 8080.0)
  assert_true(server.field("host") is None)
}

///|
test "merge lets a scalar or array override the earlier value" {
  let config = @configscope.ConfigValue::object(
    Map([("enabled", @configscope.ConfigValue::boolean(true))]),
  )
  let disabled = config.merge(@configscope.ConfigValue::boolean(false))
  assert_eq(disabled.kind().to_string(), "boolean")
  assert_eq(disabled.as_boolean().unwrap(), false)

  let fallback = @configscope.ConfigValue::string("development")
  let production = fallback.merge(
    @configscope.ConfigValue::array([
      @configscope.ConfigValue::string("us-east"),
    ]),
  )
  assert_eq(production.kind().to_string(), "array")
  assert_eq(production.element(0).unwrap().as_string().unwrap(), "us-east")
}

///|
test "deep merge preserves nested defaults and applies overrides" {
  let defaults = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([
            ("host", @configscope.ConfigValue::string("localhost")),
            (
              "http",
              @configscope.ConfigValue::object(
                Map([
                  ("port", @configscope.ConfigValue::number(80.0)),
                  ("enabled", @configscope.ConfigValue::boolean(true)),
                ]),
              ),
            ),
          ]),
        ),
      ),
      ("log_level", @configscope.ConfigValue::string("info")),
    ]),
  )
  let production = @configscope.ConfigValue::object(
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
  let merged = defaults.deep_merge(production)
  let server = merged.get(@configscope.parse_path("server").unwrap()).unwrap()
  assert_eq(server.field("host").unwrap().as_string().unwrap(), "localhost")
  let http = merged
    .get(@configscope.parse_path("server.http").unwrap())
    .unwrap()
  assert_eq(http.field("port").unwrap().as_number().unwrap(), 8080.0)
  assert_eq(http.field("enabled").unwrap().as_boolean().unwrap(), true)
  assert_eq(merged.field("log_level").unwrap().as_string().unwrap(), "info")
}

///|
test "deep merge replaces arrays, scalars, and conflicting types" {
  let defaults = @configscope.ConfigValue::object(
    Map([
      (
        "features",
        @configscope.ConfigValue::array([
          @configscope.ConfigValue::string("search"),
          @configscope.ConfigValue::string("metrics"),
        ]),
      ),
      ("enabled", @configscope.ConfigValue::boolean(true)),
      (
        "limits",
        @configscope.ConfigValue::object(
          Map([("requests", @configscope.ConfigValue::number(100.0))]),
        ),
      ),
    ]),
  )
  let later = @configscope.ConfigValue::object(
    Map([
      (
        "features",
        @configscope.ConfigValue::array([
          @configscope.ConfigValue::string("audit"),
        ]),
      ),
      ("enabled", @configscope.ConfigValue::boolean(false)),
      ("limits", @configscope.ConfigValue::number(10.0)),
    ]),
  )
  let merged = defaults.deep_merge(later)
  assert_eq(merged.field("features").unwrap().length().unwrap(), 1)
  assert_eq(
    merged.field("features").unwrap().element(0).unwrap().as_string().unwrap(),
    "audit",
  )
  assert_eq(merged.field("enabled").unwrap().as_boolean().unwrap(), false)
  assert_eq(merged.field("limits").unwrap().as_number().unwrap(), 10.0)
}

///|
test "deep merge also lets a non-object later value replace the root" {
  let defaults = @configscope.ConfigValue::object(
    Map([("name", @configscope.ConfigValue::string("development"))]),
  )
  let later = @configscope.ConfigValue::string("production")
  let merged = defaults.deep_merge(later)
  assert_eq(merged.kind().to_string(), "string")
  assert_eq(merged.as_string().unwrap(), "production")
}

///|
test "deep merge does not mutate either input" {
  let defaults = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([("port", @configscope.ConfigValue::number(80.0))]),
        ),
      ),
    ]),
  )
  let later = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([("port", @configscope.ConfigValue::number(8080.0))]),
        ),
      ),
    ]),
  )
  let _merged = defaults.deep_merge(later)
  assert_eq(
    defaults
    .get(@configscope.parse_path("server.port").unwrap())
    .unwrap()
    .as_number()
    .unwrap(),
    80.0,
  )
  assert_eq(
    later
    .get(@configscope.parse_path("server.port").unwrap())
    .unwrap()
    .as_number()
    .unwrap(),
    8080.0,
  )
}

///|
test "merge report exposes nested structural conflicts" {
  let defaults = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([
            (
              "limits",
              @configscope.ConfigValue::object(
                Map([("requests", @configscope.ConfigValue::number(100.0))]),
              ),
            ),
          ]),
        ),
      ),
    ]),
  )
  let later = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([("limits", @configscope.ConfigValue::number(10.0))]),
        ),
      ),
    ]),
  )
  let report = defaults.deep_merge_with_report(later)
  assert_eq(report.conflict_count(), 1)
  let conflict = report.conflict(0).unwrap()
  assert_true(report.conflict(1) is None)
  assert_eq(conflict.path().to_string(), "server.limits")
  assert_eq(conflict.earlier_kind().to_string(), "object")
  assert_eq(conflict.later_kind().to_string(), "number")
  assert_eq(
    report
    .value()
    .get(@configscope.parse_path("server.limits").unwrap())
    .unwrap()
    .as_number()
    .unwrap(),
    10.0,
  )
}

///|
test "merge report ignores compatible replacements" {
  let defaults = @configscope.ConfigValue::object(
    Map([
      ("port", @configscope.ConfigValue::number(80.0)),
      (
        "features",
        @configscope.ConfigValue::array([
          @configscope.ConfigValue::string("search"),
        ]),
      ),
      ("enabled", @configscope.ConfigValue::boolean(true)),
    ]),
  )
  let later = @configscope.ConfigValue::object(
    Map([
      ("port", @configscope.ConfigValue::number(8080.0)),
      (
        "features",
        @configscope.ConfigValue::array([
          @configscope.ConfigValue::string("audit"),
        ]),
      ),
      ("enabled", @configscope.ConfigValue::boolean(false)),
    ]),
  )
  let report = defaults.deep_merge_with_report(later)
  assert_eq(report.conflict_count(), 0)
}

///|
test "merge report handles root type conflicts" {
  let defaults = @configscope.ConfigValue::object(
    Map([("name", @configscope.ConfigValue::string("development"))]),
  )
  let later = @configscope.ConfigValue::string("production")
  let report = defaults.deep_merge_with_report(later)
  assert_eq(report.conflict_count(), 1)
  let conflict = report.conflict(0).unwrap()
  assert_eq(conflict.path().to_string(), "")
  assert_eq(conflict.earlier_kind().to_string(), "object")
  assert_eq(conflict.later_kind().to_string(), "string")
}

///|
test "merge report does not mutate either input" {
  let defaults = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([("port", @configscope.ConfigValue::number(80.0))]),
        ),
      ),
    ]),
  )
  let later = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([("port", @configscope.ConfigValue::number(8080.0))]),
        ),
      ),
    ]),
  )
  let _report = defaults.deep_merge_with_report(later)
  assert_eq(
    defaults
    .get(@configscope.parse_path("server.port").unwrap())
    .unwrap()
    .as_number()
    .unwrap(),
    80.0,
  )
  assert_eq(
    later
    .get(@configscope.parse_path("server.port").unwrap())
    .unwrap()
    .as_number()
    .unwrap(),
    8080.0,
  )
}

///|
test "merge report catches a scalar replaced by an object" {
  let defaults = @configscope.ConfigValue::object(
    Map([("logging", @configscope.ConfigValue::string("compact"))]),
  )
  let later = @configscope.ConfigValue::object(
    Map([
      (
        "logging",
        @configscope.ConfigValue::object(
          Map([("format", @configscope.ConfigValue::string("json"))]),
        ),
      ),
    ]),
  )
  let report = defaults.deep_merge_with_report(later)
  assert_eq(report.conflict_count(), 1)
  let conflict = report.conflict(0).unwrap()
  assert_eq(conflict.path().to_string(), "logging")
  assert_eq(conflict.earlier_kind().to_string(), "string")
  assert_eq(conflict.later_kind().to_string(), "object")
  assert_eq(
    report
    .value()
    .get(@configscope.parse_path("logging.format").unwrap())
    .unwrap()
    .as_string()
    .unwrap(),
    "json",
  )
}

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

///|
test "configuration diff reports added and removed fields" {
  let before = @configscope.ConfigValue::object(
    Map([
      ("host", @configscope.ConfigValue::string("localhost")),
      ("port", @configscope.ConfigValue::number(80.0)),
    ]),
  )
  let after = @configscope.ConfigValue::object(
    Map([
      ("port", @configscope.ConfigValue::number(80.0)),
      ("tls", @configscope.ConfigValue::boolean(true)),
    ]),
  )
  let differences = before.diff(after)
  assert_eq(differences.length(), 2)
  assert_eq(differences.get(0).unwrap().path().to_string(), "host")
  assert_eq(differences.get(0).unwrap().kind().to_string(), "removed")
  assert_true(differences.get(0).unwrap().before() is Some(_))
  assert_true(differences.get(0).unwrap().after() is None)
  assert_eq(differences.get(1).unwrap().path().to_string(), "tls")
  assert_eq(differences.get(1).unwrap().kind().to_string(), "added")
  assert_true(differences.get(1).unwrap().before() is None)
  assert_true(differences.get(1).unwrap().after() is Some(_))
}

///|
test "configuration diff reports changed scalar values" {
  let before = @configscope.ConfigValue::object(
    Map([("port", @configscope.ConfigValue::number(80.0))]),
  )
  let after = @configscope.ConfigValue::object(
    Map([("port", @configscope.ConfigValue::number(8080.0))]),
  )
  let difference = before.diff(after).get(0).unwrap()
  assert_eq(difference.path().to_string(), "port")
  assert_eq(difference.kind().to_string(), "changed")
  assert_eq(difference.before().unwrap().as_number().unwrap(), 80.0)
  assert_eq(difference.after().unwrap().as_number().unwrap(), 8080.0)
}

///|
test "configuration diff reports type changes" {
  let before = @configscope.ConfigValue::object(
    Map([("logging", @configscope.ConfigValue::string("compact"))]),
  )
  let after = @configscope.ConfigValue::object(
    Map([
      (
        "logging",
        @configscope.ConfigValue::object(
          Map([("format", @configscope.ConfigValue::string("json"))]),
        ),
      ),
    ]),
  )
  let difference = before.diff(after).get(0).unwrap()
  assert_eq(difference.path().to_string(), "logging")
  assert_eq(difference.kind().to_string(), "type_changed")
  assert_eq(difference.before().unwrap().kind().to_string(), "string")
  assert_eq(difference.after().unwrap().kind().to_string(), "object")
}

///|
test "configuration diff recurses into nested objects" {
  let before = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([
            ("host", @configscope.ConfigValue::string("localhost")),
            ("port", @configscope.ConfigValue::number(80.0)),
          ]),
        ),
      ),
    ]),
  )
  let after = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([
            ("host", @configscope.ConfigValue::string("prod")),
            ("tls", @configscope.ConfigValue::boolean(true)),
          ]),
        ),
      ),
    ]),
  )
  let differences = before.diff(after)
  assert_eq(differences.length(), 3)
  assert_eq(differences.get(0).unwrap().path().to_string(), "server.host")
  assert_eq(differences.get(0).unwrap().kind().to_string(), "changed")
  assert_eq(differences.get(1).unwrap().path().to_string(), "server.port")
  assert_eq(differences.get(1).unwrap().kind().to_string(), "removed")
  assert_eq(differences.get(2).unwrap().path().to_string(), "server.tls")
  assert_eq(differences.get(2).unwrap().kind().to_string(), "added")
}

///|
test "configuration diff treats arrays as whole values" {
  let before = @configscope.ConfigValue::array([
    @configscope.ConfigValue::string("one"),
    @configscope.ConfigValue::string("two"),
  ])
  let after = @configscope.ConfigValue::array([
    @configscope.ConfigValue::string("one"),
    @configscope.ConfigValue::string("three"),
  ])
  let differences = before.diff(after)
  assert_eq(differences.length(), 1)
  assert_eq(differences.get(0).unwrap().path().to_string(), "")
  assert_eq(differences.get(0).unwrap().kind().to_string(), "changed")
}

///|
test "configuration diff returns no changes for equal values" {
  let value = @configscope.ConfigValue::object(
    Map([("enabled", @configscope.ConfigValue::boolean(true))]),
  )
  assert_eq(value.diff(value).length(), 0)
}

///|
test "configuration diff reports root type changes" {
  let before = @configscope.ConfigValue::string("compact")
  let after = @configscope.ConfigValue::number(1.0)
  let difference = before.diff(after).get(0).unwrap()
  assert_eq(difference.path().to_string(), "")
  assert_eq(difference.kind().to_string(), "type_changed")
}

///|
test "configuration diff kind names are stable" {
  assert_eq(@configscope.ConfigDiffKind::Added.to_string(), "added")
  assert_eq(@configscope.ConfigDiffKind::Removed.to_string(), "removed")
  assert_eq(@configscope.ConfigDiffKind::Changed.to_string(), "changed")
  assert_eq(
    @configscope.ConfigDiffKind::TypeChanged.to_string(),
    "type_changed",
  )
}

///|
test "configuration diff order is independent of object insertion order" {
  let before = @configscope.ConfigValue::object(
    Map([
      ("zebra", @configscope.ConfigValue::number(1.0)),
      ("alpha", @configscope.ConfigValue::number(1.0)),
    ]),
  )
  let after = @configscope.ConfigValue::object(
    Map([
      ("middle", @configscope.ConfigValue::number(1.0)),
      ("alpha", @configscope.ConfigValue::number(2.0)),
    ]),
  )
  let differences = before.diff(after)
  assert_eq(differences.length(), 3)
  assert_eq(differences.get(0).unwrap().path().to_string(), "alpha")
  assert_eq(differences.get(1).unwrap().path().to_string(), "middle")
  assert_eq(differences.get(2).unwrap().path().to_string(), "zebra")
}

///|
test "required-path audit accepts present values" {
  let value = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([("host", @configscope.ConfigValue::string("localhost"))]),
        ),
      ),
    ]),
  )
  let rule = @configscope.ConfigAuditRule::required(
    @configscope.parse_path("server.host").unwrap(),
  )
  assert_eq(rule.path().to_string(), "server.host")
  assert_eq(value.audit([rule]).length(), 0)
}

///|
test "required-path audit reports missing nested values" {
  let value = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([("port", @configscope.ConfigValue::number(8080.0))]),
        ),
      ),
    ]),
  )
  let issue = value
    .audit([
      @configscope.ConfigAuditRule::required(
        @configscope.parse_path("server.host").unwrap(),
      ),
    ])
    .get(0)
    .unwrap()
  assert_eq(issue.path().to_string(), "server.host")
  assert_eq(issue.kind().to_string(), "missing_required")
  assert_eq(
    issue.message(),
    "required configuration path 'server.host' is missing",
  )
}

///|
test "required-path audit treats null as present" {
  let value = @configscope.ConfigValue::object(
    Map([("token", @configscope.ConfigValue::null())]),
  )
  let issues = value.audit([
    @configscope.ConfigAuditRule::required(
      @configscope.parse_path("token").unwrap(),
    ),
  ])
  assert_eq(issues.length(), 0)
}

///|
test "required-path audit reports each missing rule" {
  let value = @configscope.ConfigValue::empty_object()
  let issues = value.audit([
    @configscope.ConfigAuditRule::required(
      @configscope.parse_path("server.host").unwrap(),
    ),
    @configscope.ConfigAuditRule::required(
      @configscope.parse_path("database.url").unwrap(),
    ),
  ])
  assert_eq(issues.length(), 2)
  assert_eq(issues.get(0).unwrap().path().to_string(), "database.url")
  assert_eq(issues.get(1).unwrap().path().to_string(), "server.host")
}

///|
test "audit issue kind name is stable" {
  assert_eq(
    @configscope.ConfigAuditIssueKind::MissingRequired.to_string(),
    "missing_required",
  )
}
