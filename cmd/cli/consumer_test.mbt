///|
test "consumer-check accepts declared constraints" {
  let result = @cli.run([
    "configscope", "consumer-check", "cmd/main/testdata/basic.json", "cmd/main/testdata/consumer.json",
  ])
  assert_eq(result, Ok("consumer constraints passed (declared rules only)"))
}

///|
test "consumer-check emits JSON for both passed and rejected configurations" {
  for (file, passed) in [("basic.json", true), ("consumer-invalid.json", false)] {
    let result = @cli.run([
      "configscope",
      "consumer-check",
      "cmd/main/testdata/" + file,
      "cmd/main/testdata/consumer.json",
      "--format",
      "json",
    ])
    let output = match result {
      Ok(output) => {
        assert_true(passed)
        output
      }
      Err(output) => {
        assert_true(!passed)
        output
      }
    }
    let report = @configscope.ConfigValue::parse_json(output)
    assert_eq(
      report.field("kind").unwrap().as_string(),
      Some("consumer_report"),
    )
    assert_eq(
      report.field("scope").unwrap().as_string(),
      Some("declared_constraints"),
    )
    assert_eq(report.field("passed").unwrap().as_boolean(), Some(passed))
    assert_eq(
      report.field("issues").unwrap().length(),
      Some(if passed { 0 } else { 1 }),
    )
    assert_true(!output.contains("9999"))
    assert_true(!output.contains("allowed_values"))
  }
}

///|
test "consumer-check rejects unsupported formats" {
  assert_eq(
    @cli.run([
      "configscope", "consumer-check", "cmd/main/testdata/basic.json", "cmd/main/testdata/consumer.json",
      "--format", "xml",
    ]),
    Err("unknown --format value 'xml'; expected text or json"),
  )
}

///|
test "consumer-check reports numeric violations in JSON without values" {
  for
    (file, kind) in [
      ("consumer-workers-high.json", "above_maximum"),
      ("consumer-workers-fraction.json", "not_integer"),
    ] {
    let result = @cli.run([
      "configscope",
      "consumer-check",
      "cmd/main/testdata/" + file,
      "cmd/main/testdata/consumer.json",
      "--format",
      "json",
    ])
    let output = match result {
      Err(output) => output
      Ok(_) => abort("numeric violation must fail")
    }
    let report = @configscope.ConfigValue::parse_json(output)
    assert_eq(report.field("passed").unwrap().as_boolean(), Some(false))
    let issue = report.field("issues").unwrap().element(0).unwrap()
    assert_eq(issue.field("path").unwrap().as_string(), Some("server.workers"))
    assert_eq(issue.field("kind").unwrap().as_string(), Some(kind))
    assert_true(!issue.contains_field("value"))
    assert_true(!issue.contains_field("maximum"))
  }
}

///|
test "consumer-check reports activated cross-field requirements" {
  let result = @cli.run([
    "configscope", "consumer-check", "cmd/main/testdata/consumer-auth-missing.json",
    "cmd/main/testdata/consumer.json", "--format", "json",
  ])
  let output = match result {
    Err(output) => output
    Ok(_) => abort("enabled auth without a token must fail")
  }
  let report = @configscope.ConfigValue::parse_json(output)
  let issue = report.field("issues").unwrap().element(0).unwrap()
  assert_eq(issue.field("path").unwrap().as_string(), Some("auth.token"))
  assert_eq(issue.field("kind").unwrap().as_string(), Some("missing_required"))
  assert_true(!output.contains("fixture-only"))
}

///|
test "consumer-check rejects a disallowed value without printing it" {
  let result = @cli.run([
    "configscope", "consumer-check", "cmd/main/testdata/consumer-invalid.json", "cmd/main/testdata/consumer.json",
  ])
  assert_eq(
    result,
    Err(
      "[disallowed_value] server.port\nconsumer constraints failed: 1 violation(s)",
    ),
  )
}
