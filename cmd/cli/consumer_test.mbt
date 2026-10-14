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
