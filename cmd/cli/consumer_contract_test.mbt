///|
test "release gate accepts a valid consumer and resolves rule paths" {
  let output = @cli.run([
    "configscope", "contract-check", "cmd/main/testdata/consumer-compatible.contract.json",
    "--format", "json",
  ]).unwrap()
  let report = @configscope.ConfigValue::parse_json(output)
  assert_eq(report.field("passed").unwrap().as_boolean(), Some(true))
  let consumers = report.field("consumers").unwrap()
  assert_eq(consumers.length(), Some(1))
  assert_eq(
    consumers.element(0).unwrap().field("consumer").unwrap().as_string(),
    Some("consumer.json"),
  )
}

///|
test "ignored differences cannot disable consumer constraints" {
  let result = @cli.run([
    "configscope", "contract-check", "cmd/main/testdata/consumer-invalid.contract.json",
    "--format", "json",
  ])
  let output = match result {
    Err(output) => output
    Ok(_) => abort("must reject the candidate")
  }
  let report = @configscope.ConfigValue::parse_json(output)
  assert_eq(report.field("passed").unwrap().as_boolean(), Some(false))
  assert_eq(
    report.field("summary").unwrap().field("failed").unwrap().as_number(),
    Some(0.0),
  )
  let consumer = report.field("consumers").unwrap().element(0).unwrap()
  assert_eq(consumer.field("passed").unwrap().as_boolean(), Some(false))
  let issue = consumer.field("issues").unwrap().element(0).unwrap()
  assert_eq(issue.field("kind").unwrap().as_string(), Some("disallowed_value"))
  assert_eq(issue.field("path").unwrap().as_string(), Some("server.port"))
  assert_true(!output.contains("9999"))
}

///|
test "all declared consumer versions must pass" {
  let result = @cli.run([
    "configscope", "contract-check", "cmd/main/testdata/consumer-matrix.contract.json",
    "--format", "json",
  ])
  let output = match result {
    Err(output) => output
    Ok(_) => abort("must fail the second consumer")
  }
  let report = @configscope.ConfigValue::parse_json(output)
  let consumers = report.field("consumers").unwrap()
  assert_eq(consumers.length(), Some(2))
  assert_eq(
    consumers.element(0).unwrap().field("passed").unwrap().as_boolean(),
    Some(true),
  )
  assert_eq(
    consumers.element(1).unwrap().field("passed").unwrap().as_boolean(),
    Some(false),
  )
}

///|
test "valid consumer expectations do not bypass the structural release gate" {
  let result = @cli.run([
    "configscope", "contract-check", "cmd/main/testdata/consumer-structural-failure.contract.json",
    "--format", "json",
  ])
  let output = match result {
    Err(output) => output
    Ok(_) => abort("the structural gate must fail")
  }
  let report = @configscope.ConfigValue::parse_json(output)
  assert_eq(report.field("passed").unwrap().as_boolean(), Some(false))
  assert_eq(
    report
    .field("consumers")
    .unwrap()
    .element(0)
    .unwrap()
    .field("passed")
    .unwrap()
    .as_boolean(),
    Some(true),
  )
  assert_eq(
    report.field("summary").unwrap().field("failed").unwrap().as_number(),
    Some(1.0),
  )
}

///|
test "missing or malformed consumers fail closed" {
  for
    file in [
      "consumer-missing.contract.json", "consumer-malformed.contract.json",
    ] {
    assert_true(
      @cli.run(["configscope", "contract-check", "cmd/main/testdata/" + file])
      is Err(_),
    )
  }
}

///|
test "text release report explains consumer failure" {
  let result = @cli.run([
    "configscope", "contract-check", "cmd/main/testdata/consumer-invalid.contract.json",
  ])
  let output = match result {
    Err(output) => output
    Ok(_) => abort("must fail")
  }
  assert_true(output.contains("consumer: consumer.json"))
  assert_true(output.contains("[disallowed_value] server.port"))
  assert_true(output.contains("declared consumer constraints were violated"))
}
