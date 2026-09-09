// Black-box tests for the ConfigScope public facade.

///|
test "parse a nested configuration path" {
  let path = @configscope.parse_path("server.http.port").unwrap()
  inspect(path.length(), content="3")
  assert_eq(path.segment(0).unwrap(), "server")
  assert_eq(path.segment(1).unwrap(), "http")
  assert_eq(path.segment(2).unwrap(), "port")
  assert_true(path.segment(3) is None)
  inspect(path.to_string(), content="server.http.port")
}

///|
test "parse a single path segment" {
  let path = @configscope.parse_path("debug").unwrap()
  inspect(path.length(), content="1")
  inspect(path.to_string(), content="debug")
}

///|
test "reject empty paths and empty segments" {
  inspect(
    @configscope.parse_path("").unwrap_err().to_string(),
    content="configuration path must not be empty",
  )
  inspect(
    @configscope.parse_path(".server").unwrap_err().to_string(),
    content="configuration path segment 0 must not be empty",
  )
  inspect(
    @configscope.parse_path("server..port").unwrap_err().to_string(),
    content="configuration path segment 1 must not be empty",
  )
  inspect(
    @configscope.parse_path("server.").unwrap_err().to_string(),
    content="configuration path segment 1 must not be empty",
  )
}
