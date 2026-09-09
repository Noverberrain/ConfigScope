// Black-box tests for the ConfigScope public facade.

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
