// Black-box tests for the ConfigScope public facade.

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
