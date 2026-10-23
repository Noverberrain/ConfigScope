///|
fn release_contract() -> @configscope.ConfigConsumerContract raise {
  @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"port\",\"required\":true,\"type\":\"number\",\"minimum\":1,\"maximum\":65535},{\"path\":\"token\",\"required\":true,\"type\":\"string\"}]}",
    ),
  ).unwrap()
}

///|
fn release_binding(
  version : String,
  snapshot : String,
) -> @configscope.ConfigConsumerBinding raise {
  @configscope.ConfigConsumerBinding::new(
    "service",
    version,
    "snapshot-" + version,
    release_contract(),
    @configscope.ConfigValue::parse_json(snapshot),
  ).unwrap()
}

///|
test "versions retain their own historical snapshot and regression attribution" {
  let v1 = release_binding("v1", "{\"port\":80,\"token\":\"old\"}")
  let v2 = release_binding("v2", "{\"port\":0}")
  let report = @configscope.ConfigConsumerReleaseReport::check(
    [v2, v1],
    @configscope.ConfigValue::parse_json("{\"port\":80}"),
  ).unwrap()
  let entries = report.entries()
  assert_eq(entries[0].consumer(), "service")
  assert_eq(entries[0].version(), "v1")
  assert_eq(entries[0].baseline_id(), "snapshot-v1")
  assert_eq(entries[0].introduced()[0].path().to_string(), "token")
  assert_eq(entries[0].introduced()[0].kind(), MissingRequired)
  assert_eq(entries[0].persistent().length(), 0)
  assert_eq(entries[1].introduced().length(), 0)
  assert_eq(entries[1].persistent()[0].path().to_string(), "token")
  assert_eq(entries[1].resolved()[0].kind(), BelowMinimum)
  assert_eq(entries[1].baseline_id(), "snapshot-v2")
  assert_eq(entries[1].passes(), false)
  assert_eq(report.passes(), false)
}

///|
test "a changed issue kind at the same path is resolved plus introduced" {
  let report = @configscope.ConfigConsumerReleaseReport::check(
    [release_binding("v1", "{\"port\":\"bad\",\"token\":\"ok\"}")],
    @configscope.ConfigValue::parse_json("{\"port\":0,\"token\":\"ok\"}"),
  ).unwrap()
  let entry = report.entries()[0]
  assert_eq(entry.resolved()[0].kind(), TypeMismatch)
  assert_eq(entry.introduced()[0].kind(), BelowMinimum)
  assert_eq(entry.persistent().length(), 0)
}

///|
test "fixing all historical violations passes strict candidate acceptance" {
  let report = @configscope.ConfigConsumerReleaseReport::check(
    [release_binding("v1", "{}")],
    @configscope.ConfigValue::parse_json("{\"port\":80,\"token\":\"ok\"}"),
  ).unwrap()
  assert_eq(report.passes(), true)
  assert_eq(report.entries()[0].resolved().length(), 2)
}

///|
test "an unchanged valid candidate passes with empty regression categories" {
  let source = "{\"port\":80,\"token\":\"ok\"}"
  let report = @configscope.ConfigConsumerReleaseReport::check(
    [release_binding("v1", source)],
    @configscope.ConfigValue::parse_json(source),
  ).unwrap()
  let entry = report.entries()[0]
  assert_eq(entry.introduced().length(), 0)
  assert_eq(entry.persistent().length(), 0)
  assert_eq(entry.resolved().length(), 0)
  assert_eq(report.passes(), true)
}

///|
test "empty support sets and duplicate identities cannot produce a release pass" {
  let value = @configscope.ConfigValue::parse_json("{}")
  assert_true(
    @configscope.ConfigConsumerReleaseReport::check([], value) is Err(_),
  )
  assert_true(
    @configscope.ConfigConsumerReleaseReport::check(
      [release_binding("v1", "{}"), release_binding("v1", "{\"port\":80}")],
      value,
    )
    is Err(_),
  )
}

///|
test "binding metadata cannot be blank" {
  let value = @configscope.ConfigValue::parse_json("{}")
  for
    (name, version, baseline) in [
      ("", "v1", "a"),
      ("svc", " ", "a"),
      ("svc", "v1", "\t"),
    ] {
    assert_true(
      @configscope.ConfigConsumerBinding::new(
        name,
        version,
        baseline,
        release_contract(),
        value,
      )
      is Err(_),
    )
  }
}

///|
test "versions may bind different rules and output arrays cannot mutate the report" {
  let baseline = @configscope.ConfigValue::parse_json(
    "{\"port\":80,\"token\":\"ok\"}",
  )
  let relaxed = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"port\",\"type\":\"number\"}]}",
    ),
  ).unwrap()
  let v2 = @configscope.ConfigConsumerBinding::new(
    "service", "v2", "snapshot-v2", relaxed, baseline,
  ).unwrap()
  let bindings = [v2, release_binding("v1", "{\"port\":80,\"token\":\"ok\"}")]
  let candidate = @configscope.ConfigValue::parse_json("{\"port\":80}")
  let report = @configscope.ConfigConsumerReleaseReport::check(
    bindings, candidate,
  ).unwrap()
  assert_eq(report.entries()[1].passes(), true)
  assert_eq(report.entries()[0].passes(), false)
  assert_eq(candidate.to_json_string(), "{\"port\":80}")
  let issues = report.entries()[0].introduced()
  issues.clear()
  let entries = report.entries()
  entries.clear()
  assert_eq(report.entries().length(), 2)
  assert_eq(report.entries()[0].introduced().length(), 1)
}

///|
test "conditional activation introduces a requirement under a fixed version contract" {
  let contract = auth_contract(false)
  let binding = @configscope.ConfigConsumerBinding::new(
    "auth-service",
    "v1",
    "disabled",
    contract,
    @configscope.ConfigValue::parse_json("{}"),
  ).unwrap()
  let report = @configscope.ConfigConsumerReleaseReport::check(
    [binding],
    @configscope.ConfigValue::parse_json("{\"auth\":{\"enabled\":true}}"),
  ).unwrap()
  assert_eq(
    report.entries()[0].introduced()[0].path().to_string(),
    "auth.token",
  )
  assert_eq(report.entries()[0].persistent().length(), 0)
  assert_eq(report.passes(), false)
}

///|
test "defaults are applied consistently when checking both snapshots" {
  let contract = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"port\",\"required\":true,\"type\":\"number\",\"default\":80}]}",
    ),
  ).unwrap()
  let binding = @configscope.ConfigConsumerBinding::new(
    "service",
    "v1",
    "explicit",
    contract,
    @configscope.ConfigValue::parse_json("{\"port\":80}"),
  ).unwrap()
  let report = @configscope.ConfigConsumerReleaseReport::check(
    [binding],
    @configscope.ConfigValue::parse_json("{}"),
  ).unwrap()
  assert_eq(report.passes(), true)
  assert_eq(report.entries()[0].introduced().length(), 0)
}
