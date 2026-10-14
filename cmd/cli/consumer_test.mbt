///|
test "consumer-check accepts declared constraints" {
  let result = @cli.run([
    "configscope", "consumer-check", "cmd/main/testdata/basic.json", "cmd/main/testdata/consumer.json",
  ])
  assert_eq(result, Ok("consumer constraints passed (declared rules only)"))
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
