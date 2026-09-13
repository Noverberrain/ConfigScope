///|
test "compat-matrix accepts all baselines" {
  assert_eq(
    @cli.run([
      "configscope", "compat-matrix", "cmd/main/testdata/compatibility-compatible.json",
      "cmd/main/testdata/basic.json",
    ]),
    Ok(
      "gate: breaking\n" +
      "baseline: cmd/main/testdata/basic.json\n" +
      "  [behavioral] changed: features\n" +
      "  [compatible] added: logging\n" +
      "  [behavioral] changed: server.port\n" +
      "result: passed\n" +
      "summary: passed=1 failed=0 total=1\n" +
      "compatibility matrix passed",
    ),
  )
}

///|
test "compat-matrix reports each failing baseline" {
  assert_eq(
    @cli.run([
      "configscope", "compat-matrix", "cmd/main/testdata/compatibility-compatible.json",
      "cmd/main/testdata/basic.json", "cmd/main/testdata/compatibility-breaking.json",
    ]),
    Err(
      "gate: breaking\n" +
      "baseline: cmd/main/testdata/basic.json\n" +
      "  [behavioral] changed: features\n" +
      "  [compatible] added: logging\n" +
      "  [behavioral] changed: server.port\n" +
      "result: passed\n" +
      "baseline: cmd/main/testdata/compatibility-breaking.json\n" +
      "  [compatible] added: features\n" +
      "  [compatible] added: logging\n" +
      "  [breaking] type_changed: server.port\n" +
      "result: failed (1 gate violation)\n" +
      "summary: passed=1 failed=1 total=2\n" +
      "compatibility matrix failed: 1 baseline exceeds the 'breaking' gate",
    ),
  )
}

///|
test "compat-matrix supports stricter gates" {
  assert_eq(
    @cli.run([
      "configscope", "compat-matrix", "cmd/main/testdata/compatibility-compatible.json",
      "cmd/main/testdata/basic.json", "--fail-on", "behavioral",
    ]),
    Err(
      "gate: behavioral\n" +
      "baseline: cmd/main/testdata/basic.json\n" +
      "  [behavioral] changed: features\n" +
      "  [compatible] added: logging\n" +
      "  [behavioral] changed: server.port\n" +
      "result: failed (2 gate violations)\n" +
      "summary: passed=0 failed=1 total=1\n" +
      "compatibility matrix failed: 1 baseline exceeds the 'behavioral' gate",
    ),
  )
}

///|
test "compat-matrix validates inputs" {
  assert_eq(
    @cli.run(["configscope", "compat-matrix", "cmd/main/testdata/basic.json"]),
    Err("compat-matrix requires at least one baseline file"),
  )
  assert_eq(
    @cli.run([
      "configscope", "compat-matrix", "cmd/main/testdata/basic.json", "missing.json",
    ]),
    Err("file 'missing.json' does not exist"),
  )
}
