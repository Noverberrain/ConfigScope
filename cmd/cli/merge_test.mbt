///|
test "merge combines JSON layers in order" {
  assert_eq(
    @cli.run([
      "configscope", "merge", "cmd/main/testdata/basic.json", "cmd/main/testdata/production.json",
    ]),
    Ok(
      "{\"server\":{\"host\":\"localhost\",\"port\":9090}," +
      "\"features\":[\"audit\",\"diff\",\"merge\"]," +
      "\"logging\":{\"level\":\"info\"}}",
    ),
  )
}

///|
test "merge accepts more than two layers" {
  assert_eq(
    @cli.run([
      "configscope", "merge", "cmd/main/testdata/basic.json", "cmd/main/testdata/production.json",
      "cmd/main/testdata/basic.json",
    ]),
    Ok(
      "{\"server\":{\"host\":\"localhost\",\"port\":8080}," +
      "\"features\":[\"audit\",\"diff\"]," +
      "\"logging\":{\"level\":\"info\"}}",
    ),
  )
}

///|
test "merge reports missing input files" {
  assert_eq(
    @cli.run([
      "configscope", "merge", "cmd/main/testdata/basic.json", "missing.json",
    ]),
    Err("file 'missing.json' does not exist"),
  )
}

///|
test "merge requires at least two files" {
  assert_eq(
    @cli.run(["configscope", "merge", "cmd/main/testdata/basic.json"]),
    Err(@cli.usage()),
  )
}
