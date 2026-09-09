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

///|
test "audit accepts required and type rules" {
  assert_eq(
    @cli.run([
      "configscope", "audit", "cmd/main/testdata/basic.json", "--required", "server.host",
      "--type", "server.port:number",
    ]),
    Ok("audit passed"),
  )
}

///|
test "audit reports all issues in path order" {
  assert_eq(
    @cli.run([
      "configscope", "audit", "cmd/main/testdata/basic.json", "--required", "server.missing",
      "--type", "server.host:number",
    ]),
    Err(
      "configuration path 'server.host' expected number, but found string\n" +
      "required configuration path 'server.missing' is missing",
    ),
  )
}

///|
test "audit rejects unknown kinds" {
  assert_eq(
    @cli.run([
      "configscope", "audit", "cmd/main/testdata/basic.json", "--type", "server.port:integer",
    ]),
    Err(
      "unknown configuration kind 'integer'; expected null, boolean, number, string, array, or object",
    ),
  )
}

///|
test "audit requires rules and recognizes options" {
  assert_eq(
    @cli.run(["configscope", "audit", "cmd/main/testdata/basic.json"]),
    Err("audit requires at least one --required or --type rule"),
  )
  assert_eq(
    @cli.run([
      "configscope", "audit", "cmd/main/testdata/basic.json", "--optional", "server.host",
    ]),
    Err("unknown audit option '--optional'"),
  )
}

///|
test "audit rejects incomplete options" {
  assert_eq(
    @cli.run([
      "configscope", "audit", "cmd/main/testdata/basic.json", "--required",
    ]),
    Err("missing path after --required"),
  )
  assert_eq(
    @cli.run([
      "configscope", "audit", "cmd/main/testdata/basic.json", "--type", "server.port",
    ]),
    Err("type rule must use <path>:<kind>"),
  )
}
