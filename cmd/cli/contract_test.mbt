///|
test "contract-check resolves paths relative to the manifest" {
  assert_eq(
    @cli.run([
      "configscope", "contract-check", "cmd/main/testdata/configscope-compatible.contract.json",
    ]),
    Ok(
      "contract: cmd/main/testdata/configscope-compatible.contract.json\n" +
      "candidate: compatibility-compatible.json\n" +
      "gate: breaking\n" +
      "baseline: basic.json\n" +
      "  [behavioral] changed: features\n" +
      "  [compatible] added: logging\n" +
      "  [behavioral] changed: server.port\n" +
      "result: passed\n" +
      "summary: passed=1 failed=0 total=1\n" +
      "compatibility contract passed",
    ),
  )
}

///|
test "contract-check applies the manifest release gate" {
  assert_eq(
    @cli.run([
      "configscope", "contract-check", "cmd/main/testdata/configscope-breaking.contract.json",
    ]),
    Err(
      "contract: cmd/main/testdata/configscope-breaking.contract.json\n" +
      "candidate: compatibility-breaking.json\n" +
      "gate: breaking\n" +
      "baseline: basic.json\n" +
      "  [breaking] removed: features\n" +
      "  [breaking] type_changed: server.port\n" +
      "result: failed (2 gate violations)\n" +
      "summary: passed=0 failed=1 total=1\n" +
      "compatibility contract failed: 1 baseline exceeds the 'breaking' gate",
    ),
  )
}

///|
test "contract-check excludes exact ignored paths" {
  assert_eq(
    @cli.run([
      "configscope", "contract-check", "cmd/main/testdata/configscope-ignored.contract.json",
    ]),
    Ok(
      "contract: cmd/main/testdata/configscope-ignored.contract.json\n" +
      "candidate: compatibility-breaking.json\n" +
      "ignored paths: features, server.port\n" +
      "gate: breaking\n" +
      "baseline: basic.json\n" +
      "result: passed\n" +
      "summary: passed=1 failed=0 total=1\n" +
      "compatibility contract passed",
    ),
  )
}

///|
test "contract-check reports invalid manifests" {
  assert_eq(
    @cli.run(["configscope", "contract-check", "cmd/main/testdata/basic.json"]),
    Err(
      "invalid compatibility contract 'cmd/main/testdata/basic.json': " +
      "contract is missing required field 'candidate'",
    ),
  )
}

///|
test "contract-check reports missing referenced snapshots" {
  assert_eq(
    @cli.run([
      "configscope", "contract-check", "cmd/main/testdata/configscope-missing.contract.json",
    ]),
    Err("contract candidate file 'missing.json' does not exist"),
  )
}

///|
test "contract-check emits machine-readable JSON" {
  let output = @cli.run([
    "configscope", "contract-check", "cmd/main/testdata/configscope-compatible.contract.json",
    "--format", "json",
  ]).unwrap()
  let value = @configscope.ConfigValue::parse_json(output)
  assert_eq(
    value.field("kind").unwrap().as_string(),
    Some("compatibility_contract"),
  )
  assert_eq(value.field("passed").unwrap().as_boolean(), Some(true))
  assert_eq(value.field("gate").unwrap().as_string(), Some("breaking"))
  assert_eq(value.field("ignore_paths").unwrap().length(), Some(0))
}

///|
test "contract-check reports ignored paths in JSON" {
  let output = @cli.run([
    "configscope", "contract-check", "cmd/main/testdata/configscope-ignored.contract.json",
    "--format", "json",
  ]).unwrap()
  let value = @configscope.ConfigValue::parse_json(output)
  let ignored = value.field("ignore_paths").unwrap()
  assert_eq(ignored.element(0).unwrap().as_string(), Some("features"))
  assert_eq(ignored.element(1).unwrap().as_string(), Some("server.port"))
  assert_eq(value.field("passed").unwrap().as_boolean(), Some(true))
}
