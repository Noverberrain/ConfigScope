///|
test "compat accepts compatible and behavioral changes" {
  assert_eq(
    @cli.run([
      "configscope", "compat", "cmd/main/testdata/basic.json", "cmd/main/testdata/compatibility-compatible.json",
    ]),
    Ok(
      "gate: breaking\n" +
      "[behavioral] changed: features\n" +
      "[compatible] added: logging\n" +
      "[behavioral] changed: server.port\n" +
      "summary: compatible=1 behavioral=2 breaking=0\n" +
      "compatibility check passed",
    ),
  )
}

///|
test "compat rejects breaking changes" {
  assert_eq(
    @cli.run([
      "configscope", "compat", "cmd/main/testdata/basic.json", "cmd/main/testdata/compatibility-breaking.json",
    ]),
    Err(
      "gate: breaking\n" +
      "[breaking] removed: features\n" +
      "[breaking] type_changed: server.port\n" +
      "summary: compatible=0 behavioral=0 breaking=2\n" +
      "compatibility check failed: 2 changes exceed the 'breaking' gate",
    ),
  )
}

///|
test "compat accepts identical snapshots" {
  assert_eq(
    @cli.run([
      "configscope", "compat", "cmd/main/testdata/basic.json", "cmd/main/testdata/basic.json",
    ]),
    Ok(
      "gate: breaking\n" +
      "summary: compatible=0 behavioral=0 breaking=0\n" +
      "compatibility check passed",
    ),
  )
}

///|
test "compat reports input errors" {
  assert_eq(
    @cli.run([
      "configscope", "compat", "missing.json", "cmd/main/testdata/basic.json",
    ]),
    Err("file 'missing.json' does not exist"),
  )
  assert_eq(
    @cli.run([
      "configscope", "compat", "cmd/main/testdata/invalid.json", "cmd/main/testdata/basic.json",
    ]),
    Err("invalid JSON in 'cmd/main/testdata/invalid.json'"),
  )
}

///|
test "compat validates its arguments" {
  assert_eq(
    @cli.run(["configscope", "compat", "cmd/main/testdata/basic.json"]),
    Err(@cli.usage()),
  )
}

///|
test "compat can fail on behavioral changes" {
  assert_eq(
    @cli.run([
      "configscope", "compat", "cmd/main/testdata/basic.json", "cmd/main/testdata/compatibility-compatible.json",
      "--fail-on", "behavioral",
    ]),
    Err(
      "gate: behavioral\n" +
      "[behavioral] changed: features\n" +
      "[compatible] added: logging\n" +
      "[behavioral] changed: server.port\n" +
      "summary: compatible=1 behavioral=2 breaking=0\n" +
      "compatibility check failed: 2 changes exceed the 'behavioral' gate",
    ),
  )
}

///|
test "compat can fail on every change" {
  assert_eq(
    @cli.run([
      "configscope", "compat", "cmd/main/testdata/basic.json", "cmd/main/testdata/compatibility-compatible.json",
      "--fail-on", "any",
    ]),
    Err(
      "gate: any\n" +
      "[behavioral] changed: features\n" +
      "[compatible] added: logging\n" +
      "[behavioral] changed: server.port\n" +
      "summary: compatible=1 behavioral=2 breaking=0\n" +
      "compatibility check failed: 3 changes exceed the 'any' gate",
    ),
  )
}

///|
test "compat validates gate options" {
  assert_eq(
    @cli.run([
      "configscope", "compat", "cmd/main/testdata/basic.json", "cmd/main/testdata/basic.json",
      "--fail-on", "strict",
    ]),
    Err(
      "unknown --fail-on value 'strict'; expected breaking, behavioral, or any",
    ),
  )
  assert_eq(
    @cli.run([
      "configscope", "compat", "cmd/main/testdata/basic.json", "cmd/main/testdata/basic.json",
      "--fail-on",
    ]),
    Err("missing value after --fail-on"),
  )
  assert_eq(
    @cli.run([
      "configscope", "compat", "cmd/main/testdata/basic.json", "cmd/main/testdata/basic.json",
      "--verbose",
    ]),
    Err("unknown compat option '--verbose'"),
  )
}
