///|
test "redact replaces selected nested paths" {
  let value = ConfigValue::parse_json(
    "{\"server\":{\"host\":\"localhost\",\"password\":\"secret\"}}",
  )
  let redacted = value.redact([parse_path("server.password").unwrap()])
  assert_eq(
    redacted.to_json_string(),
    "{\"server\":{\"host\":\"localhost\",\"password\":\"[REDACTED]\"}}",
  )
}

///|
test "redact leaves unrelated values and supports the root" {
  let value = ConfigValue::parse_json("{\"token\":\"secret\",\"port\":80}")
  let unchanged = value.redact([])
  assert_eq(unchanged, value)
  let root = value.redact([parse_path("token").unwrap()])
  assert_eq(root.field("port").unwrap().as_number(), Some(80.0))
  assert_eq(root.field("token").unwrap().as_string(), Some("[REDACTED]"))
}
