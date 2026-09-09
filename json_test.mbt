// Black-box tests for the ConfigScope public facade.

///|
test "json parsing builds nested configuration values" {
  let value = @configscope.ConfigValue::parse_json(
    "{\"server\":{\"port\":8080,\"tls\":true},\"tags\":[\"dev\",null]}",
  )
  assert_eq(
    value
    .get(@configscope.parse_path("server.port").unwrap())
    .unwrap()
    .as_number(),
    Some(8080.0),
  )
  assert_eq(
    value
    .get(@configscope.parse_path("server.tls").unwrap())
    .unwrap()
    .as_boolean(),
    Some(true),
  )
  assert_eq(
    value.get(@configscope.parse_path("tags").unwrap()).unwrap().length(),
    Some(2),
  )
}

///|
test "json parsing accepts root values" {
  assert_eq(@configscope.ConfigValue::parse_json("null").kind(), Null)
  assert_eq(@configscope.ConfigValue::parse_json("[1,2]").kind(), Array)
}
