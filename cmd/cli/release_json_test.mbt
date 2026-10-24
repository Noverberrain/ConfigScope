///|
fn release_json_report(
  file : String,
  passed : Bool,
) -> @configscope.ConfigValue raise {
  let result = @cli.run([
    "configscope",
    "release-check",
    "cmd/main/testdata/release/" + file,
    "--format",
    "json",
  ])
  let text = match result {
    Ok(text) => {
      assert_eq(passed, true)
      text
    }
    Err(text) => {
      assert_eq(passed, false)
      text
    }
  }
  assert_eq(text.contains("SENSITIVE_RELEASE_FIXTURE"), false)
  let value = @configscope.ConfigValue::parse_json(text)
  assert_eq(
    value.field("kind").unwrap().as_string(),
    Some("consumer_release_report"),
  )
  assert_eq(value.field("schema_version").unwrap().as_number(), Some(1.0))
  assert_eq(
    value.field("scope").unwrap().as_string(),
    Some("declared_consumer_versions"),
  )
  assert_eq(value.field("passed").unwrap().as_boolean(), Some(passed))
  assert_eq(
    value.field("decision").unwrap().as_string(),
    Some(if passed { "allowed" } else { "blocked" }),
  )
  value
}

///|
test "release JSON separates candidate acceptance from strict release decision" {
  let report = release_json_report("preserve.release.json", false)
  assert_eq(
    report.field("candidate_accepted").unwrap().as_boolean(),
    Some(true),
  )
  assert_eq(
    report.field("policy").unwrap().as_string(),
    Some("preserve-effective"),
  )
  let summary = report.field("summary").unwrap()
  assert_eq(summary.field("allowed").unwrap().as_number(), Some(1.0))
  assert_eq(summary.field("blocked").unwrap().as_number(), Some(1.0))
  let versions = report.field("consumers").unwrap()
  assert_eq(
    versions.element(0).unwrap().field("version").unwrap().as_string(),
    Some("v1"),
  )
  let v2 = versions.element(1).unwrap()
  assert_eq(v2.field("baseline_id").unwrap().as_string(), Some("release-30"))
  assert_eq(v2.field("contract").unwrap().as_string(), Some("v2.json"))
  assert_eq(v2.field("baseline").unwrap().as_string(), Some("historical.json"))
  let blocker = v2.field("blockers").unwrap().element(0).unwrap()
  assert_eq(
    blocker.field("reason").unwrap().as_string(),
    Some("effective_value_changed"),
  )
  assert_eq(blocker.field("path").unwrap().as_string(), Some("timeout"))
}

///|
test "default accept JSON records effective changes without blocking" {
  let report = release_json_report("defaults.release.json", true)
  assert_eq(report.field("policy").unwrap().as_string(), Some("accept"))
  let v2 = report.field("consumers").unwrap().element(1).unwrap()
  assert_eq(v2.field("release_allowed").unwrap().as_boolean(), Some(true))
  assert_eq(
    v2.field("effective_values_preserved").unwrap().as_boolean(),
    Some(false),
  )
  assert_eq(v2.field("blockers").unwrap().length(), Some(0))
  let change = v2.field("effective_changes").unwrap().element(0).unwrap()
  assert_eq(change.field("before").unwrap().as_string(), Some("explicit"))
  assert_eq(change.field("after").unwrap().as_string(), Some("default"))
  assert_eq(change.field("value_changed").unwrap().as_boolean(), Some(true))
  assert_eq(change.contains_field("value"), false)
}

///|
test "incomparable JSON uses null instead of falsely claiming preservation" {
  let report = release_json_report("preserve-unknown.release.json", false)
  assert_eq(
    report.field("candidate_accepted").unwrap().as_boolean(),
    Some(true),
  )
  let entry = report.field("consumers").unwrap().element(0).unwrap()
  assert_eq(
    entry.field("effective_comparable").unwrap().as_boolean(),
    Some(false),
  )
  assert_eq(entry.field("effective_values_preserved").unwrap().kind(), Null)
  assert_eq(entry.field("effective_changes").unwrap().length(), Some(0))
  let blocker = entry.field("blockers").unwrap().element(0).unwrap()
  assert_eq(
    blocker.field("reason").unwrap().as_string(),
    Some("effective_incomparable"),
  )
  assert_eq(blocker.field("path").unwrap().kind(), Null)
  assert_eq(
    entry
    .field("resolved")
    .unwrap()
    .element(0)
    .unwrap()
    .field("kind")
    .unwrap()
    .as_string(),
    Some("above_maximum"),
  )
}

///|
test "release JSON supports accepted provenance changes and rejected candidate constraints" {
  let accepted = release_json_report("preserve-equal.release.json", true)
  assert_eq(
    accepted.field("summary").unwrap().field("total").unwrap().as_number(),
    Some(1.0),
  )
  let rejected = release_json_report("rejected.release.json", false)
  assert_eq(
    rejected.field("candidate_accepted").unwrap().as_boolean(),
    Some(false),
  )
  let v2 = rejected.field("consumers").unwrap().element(1).unwrap()
  assert_eq(
    v2
    .field("introduced")
    .unwrap()
    .element(0)
    .unwrap()
    .field("kind")
    .unwrap()
    .as_string(),
    Some("above_maximum"),
  )
  assert_eq(
    v2
    .field("blockers")
    .unwrap()
    .element(0)
    .unwrap()
    .field("reason")
    .unwrap()
    .as_string(),
    Some("candidate_above_maximum"),
  )
}

///|
test "release JSON errors remain text and explicit text format preserves output" {
  let missing = @cli.run([
    "configscope", "release-check", "cmd/main/testdata/release/absent.json", "--format",
    "json",
  ])
  assert_eq(
    missing,
    Err("file 'cmd/main/testdata/release/absent.json' does not exist"),
  )
  assert_eq(
    @cli.run(["configscope", "release-check", "ignored.json", "--format", "xml"]),
    Err("unknown --format value 'xml'; expected text or json"),
  )
  let file = "cmd/main/testdata/release/defaults.release.json"
  assert_eq(
    @cli.run(["configscope", "release-check", file]),
    @cli.run(["configscope", "release-check", file, "--format", "text"]),
  )
  assert_eq(
    release_json_report("defaults.release.json", true),
    release_json_report("defaults.release.json", true),
  )
}
