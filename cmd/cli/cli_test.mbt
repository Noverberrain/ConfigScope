///|
test "usage exposes only compatibility commands" {
  assert_eq(
    @cli.usage(),
    "Usage:\n  configscope compat <before.json> <after.json> [--fail-on breaking|behavioral|any]\n  configscope compat-matrix <candidate.json> <baseline.json>... [--fail-on breaking|behavioral|any]",
  )
}

///|
test "legacy get command is outside the primary CLI" {
  assert_eq(
    @cli.run([
      "configscope", "get", "cmd/main/testdata/basic.json", "server.port",
    ]),
    Err(@cli.usage()),
  )
}

///|
test "legacy audit command is outside the primary CLI" {
  assert_eq(
    @cli.run([
      "configscope", "audit", "cmd/main/testdata/basic.json", "--required", "server.host",
    ]),
    Err(@cli.usage()),
  )
}

///|
test "legacy merge command is outside the primary CLI" {
  assert_eq(
    @cli.run([
      "configscope", "merge", "cmd/main/testdata/basic.json", "cmd/main/testdata/production.json",
    ]),
    Err(@cli.usage()),
  )
}
