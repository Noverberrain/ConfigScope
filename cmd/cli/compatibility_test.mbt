///|
test "compat accepts compatible and behavioral changes" {
  assert_eq(
    @cli.run([
      "configscope", "compat", "cmd/main/testdata/basic.json", "cmd/main/testdata/compatibility-compatible.json",
    ]),
    Ok(
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
      "[breaking] removed: features\n" +
      "[breaking] type_changed: server.port\n" +
      "summary: compatible=0 behavioral=0 breaking=2\n" +
      "compatibility check failed: 2 breaking changes detected",
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
