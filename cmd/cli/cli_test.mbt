///|
test "get returns a nested JSON value" {
  assert_eq(
    @cli.run([
      "configscope", "get", "cmd/main/testdata/basic.json", "server.port",
    ]),
    Ok("8080"),
  )
}

///|
test "get returns arrays as JSON" {
  assert_eq(
    @cli.run(["configscope", "get", "cmd/main/testdata/basic.json", "features"]),
    Ok("[\"audit\",\"diff\"]"),
  )
}

///|
test "get reports missing paths" {
  assert_eq(
    @cli.run([
      "configscope", "get", "cmd/main/testdata/basic.json", "server.missing",
    ]),
    Err("configuration path 'server.missing' was not found"),
  )
}

///|
test "get reports malformed paths" {
  assert_eq(
    @cli.run([
      "configscope", "get", "cmd/main/testdata/basic.json", "server..port",
    ]),
    Err(
      "invalid configuration path 'server..port': configuration path segment 1 must not be empty",
    ),
  )
}

///|
test "get reports missing files" {
  assert_eq(
    @cli.run(["configscope", "get", "missing.json", "server.port"]),
    Err("file 'missing.json' does not exist"),
  )
}

///|
test "get reports malformed JSON" {
  assert_eq(
    @cli.run([
      "configscope", "get", "cmd/main/testdata/invalid.json", "server.port",
    ]),
    Err("invalid JSON in 'cmd/main/testdata/invalid.json'"),
  )
}

///|
test "get reports invalid arguments" {
  assert_eq(@cli.run(["configscope", "audit"]), Err(@cli.usage()))
}
