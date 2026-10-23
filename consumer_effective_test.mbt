///|
fn effective_binding(
  version : String,
  rules : String,
  baseline : String,
) -> @configscope.ConfigConsumerBinding raise {
  @configscope.ConfigConsumerBinding::new(
    "service",
    version,
    "snapshot-" + version,
    @configscope.ConfigConsumerContract::from_value(
      @configscope.ConfigValue::parse_json(rules),
    ).unwrap(),
    @configscope.ConfigValue::parse_json(baseline),
  ).unwrap()
}

///|
fn effective_report(
  rules : String,
  baseline : String,
  candidate : String,
) -> @configscope.ConfigConsumerReleaseReport raise {
  @configscope.ConfigConsumerReleaseReport::check(
    [effective_binding("v1", rules, baseline)],
    @configscope.ConfigValue::parse_json(candidate),
  ).unwrap()
}

///|
test "deletion is provenance-only for v1 but changes the effective value for v2" {
  let v1 = effective_binding(
    "v1", "{\"rules\":[{\"path\":\"timeout\",\"type\":\"number\",\"minimum\":1,\"maximum\":60,\"default\":30}]}",
    "{\"timeout\":30}",
  )
  let v2 = effective_binding(
    "v2", "{\"rules\":[{\"path\":\"timeout\",\"type\":\"number\",\"minimum\":1,\"maximum\":60,\"default\":10}]}",
    "{\"timeout\":30}",
  )
  let candidate = @configscope.ConfigValue::parse_json("{}")
  let report = @configscope.ConfigConsumerReleaseReport::check(
    [v2, v1],
    candidate,
  ).unwrap()
  assert_eq(report.passes(), true)
  assert_eq(report.preserves_effective_values(), false)
  let entries = report.entries()
  assert_eq(entries[0].effective_comparable(), true)
  assert_eq(entries[0].preserves_effective_values(), true)
  assert_eq(entries[1].preserves_effective_values(), false)
  for entry in entries {
    let change = entry.effective_changes()[0]
    assert_eq(change.path().to_string(), "timeout")
    assert_eq(change.before(), Explicit)
    assert_eq(change.after(), Default)
  }
  assert_eq(entries[0].effective_changes()[0].value_changed(), false)
  assert_eq(entries[1].effective_changes()[0].value_changed(), true)
  assert_eq(candidate.to_json_string(), "{}")
}

///|
test "explicit to explicit legal changes are distinct from validation failures" {
  let report = effective_report(
    "{\"rules\":[{\"path\":\"port\",\"type\":\"number\"}]}", "{\"port\":80}", "{\"port\":81}",
  )
  assert_eq(report.passes(), true)
  assert_eq(report.preserves_effective_values(), false)
  let change = report.entries()[0].effective_changes()[0]
  assert_eq(change.before(), Explicit)
  assert_eq(change.after(), Explicit)
  assert_eq(change.value_changed(), true)
}

///|
test "missing is not explicit null and neither is default substitution" {
  let report = effective_report(
    "{\"rules\":[{\"path\":\"token\",\"type\":\"null\"}]}", "{}", "{\"token\":null}",
  )
  let change = report.entries()[0].effective_changes()[0]
  assert_eq(change.before(), Missing)
  assert_eq(change.after(), Explicit)
  assert_eq(change.value_changed(), true)
  let defaulted = effective_report(
    "{\"rules\":[{\"path\":\"token\",\"allowed_values\":[null,\"secret\"],\"default\":\"secret\"}]}",
    "{}", "{\"token\":null}",
  )
  assert_eq(defaulted.entries()[0].effective_changes()[0].before(), Default)
  assert_eq(defaulted.preserves_effective_values(), false)
}

///|
test "default to equal explicit value preserves selection but records provenance" {
  let report = effective_report(
    "{\"rules\":[{\"path\":\"port\",\"type\":\"number\",\"default\":80}]}", "{}",
    "{\"port\":80}",
  )
  let entry = report.entries()[0]
  assert_eq(entry.preserves_effective_values(), true)
  assert_eq(entry.effective_changes()[0].before(), Default)
  assert_eq(entry.effective_changes()[0].after(), Explicit)
  let copy = entry.effective_changes()
  copy.clear()
  assert_eq(entry.effective_changes().length(), 1)
}

///|
test "invalid history is unknown even after all violations are fixed" {
  let report = effective_report(
    "{\"rules\":[{\"path\":\"port\",\"required\":true,\"type\":\"number\"}]}", "{}",
    "{\"port\":80}",
  )
  assert_eq(report.passes(), true)
  assert_eq(report.entries()[0].effective_comparable(), false)
  assert_eq(report.entries()[0].effective_changes().length(), 0)
  assert_eq(report.preserves_effective_values(), false)
}

///|
test "invalid candidate and blocked parent cannot masquerade as default fallback" {
  let report = effective_report(
    "{\"rules\":[{\"path\":\"server.port\",\"type\":\"number\",\"default\":80}]}",
    "{}", "{\"server\":null}",
  )
  assert_eq(report.passes(), false)
  assert_eq(report.entries()[0].effective_comparable(), false)
  assert_eq(report.preserves_effective_values(), false)
}

///|
test "conditional activation and deactivation are observable selection changes" {
  let rules = "{\"rules\":[{\"path\":\"enabled\",\"type\":\"boolean\",\"default\":false},{\"path\":\"token\",\"type\":\"string\",\"when\":{\"path\":\"enabled\",\"equals\":true}}]}"
  let activated = effective_report(rules, "{}", "{\"enabled\":true}")
  let changes = activated.entries()[0].effective_changes()
  assert_eq(changes.length(), 2)
  assert_eq(changes[0].path().to_string(), "enabled")
  assert_eq(changes[1].path().to_string(), "token")
  assert_eq(changes[1].before(), Inactive)
  assert_eq(changes[1].after(), Missing)
  assert_eq(changes[1].value_changed(), true)
  let deactivated = effective_report(
    rules, "{\"enabled\":true,\"token\":\"secret\"}", "{}",
  )
  assert_eq(deactivated.entries()[0].effective_changes()[1].after(), Inactive)
  assert_eq(deactivated.preserves_effective_values(), false)
}

///|
test "inactive fields and undeclared paths are not interpreted as consumer reads" {
  let report = effective_report(
    "{\"rules\":[{\"path\":\"enabled\",\"type\":\"boolean\",\"default\":false},{\"path\":\"token\",\"type\":\"string\",\"when\":{\"path\":\"enabled\",\"equals\":true}}]}",
    "{\"token\":\"old\",\"other\":1}", "{\"token\":\"new\",\"other\":2}",
  )
  assert_eq(report.entries()[0].effective_changes().length(), 0)
  assert_eq(report.preserves_effective_values(), true)
}

///|
test "objects compare structurally and arrays compare as whole values" {
  let rules = "{\"rules\":[{\"path\":\"data\",\"type\":\"object\"}]}"
  let equal = effective_report(
    rules, "{\"data\":{\"a\":1,\"b\":2}}", "{\"data\":{\"b\":2,\"a\":1}}",
  )
  assert_eq(equal.preserves_effective_values(), true)
  let array_rules = "{\"rules\":[{\"path\":\"data\",\"type\":\"array\"}]}"
  let array = effective_report(
    array_rules, "{\"data\":[1,2]}", "{\"data\":[2,1]}",
  )
  assert_eq(
    array.entries()[0].effective_changes()[0].path().to_string(),
    "data",
  )
  assert_eq(array.preserves_effective_values(), false)
}
