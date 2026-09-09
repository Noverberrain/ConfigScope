// Black-box tests for the ConfigScope public facade.

///|
test "required-path audit accepts present values" {
  let value = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([("host", @configscope.ConfigValue::string("localhost"))]),
        ),
      ),
    ]),
  )
  let rule = @configscope.ConfigAuditRule::required(
    @configscope.parse_path("server.host").unwrap(),
  )
  assert_eq(rule.path().to_string(), "server.host")
  assert_eq(value.audit([rule]).length(), 0)
}

///|
test "required-path audit reports missing nested values" {
  let value = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([("port", @configscope.ConfigValue::number(8080.0))]),
        ),
      ),
    ]),
  )
  let issue = value
    .audit([
      @configscope.ConfigAuditRule::required(
        @configscope.parse_path("server.host").unwrap(),
      ),
    ])
    .get(0)
    .unwrap()
  assert_eq(issue.path().to_string(), "server.host")
  assert_eq(issue.kind().to_string(), "missing_required")
  assert_eq(
    issue.message(),
    "required configuration path 'server.host' is missing",
  )
}

///|
test "required-path audit treats null as present" {
  let value = @configscope.ConfigValue::object(
    Map([("token", @configscope.ConfigValue::null())]),
  )
  let issues = value.audit([
    @configscope.ConfigAuditRule::required(
      @configscope.parse_path("token").unwrap(),
    ),
  ])
  assert_eq(issues.length(), 0)
}

///|
test "required-path audit reports each missing rule" {
  let value = @configscope.ConfigValue::empty_object()
  let issues = value.audit([
    @configscope.ConfigAuditRule::required(
      @configscope.parse_path("server.host").unwrap(),
    ),
    @configscope.ConfigAuditRule::required(
      @configscope.parse_path("database.url").unwrap(),
    ),
  ])
  assert_eq(issues.length(), 2)
  assert_eq(issues.get(0).unwrap().path().to_string(), "database.url")
  assert_eq(issues.get(1).unwrap().path().to_string(), "server.host")
}

///|
test "audit issue kind name is stable" {
  assert_eq(
    ConfigAuditIssueKind::MissingRequired.to_string(),
    "missing_required",
  )
}

///|
test "type audit accepts the expected kind" {
  let value = @configscope.ConfigValue::object(
    Map([("port", @configscope.ConfigValue::number(8080.0))]),
  )
  let rule = @configscope.ConfigAuditRule::type_is(
    @configscope.parse_path("port").unwrap(),
    Number,
  )
  assert_eq(rule.path().to_string(), "port")
  assert_eq(value.audit([rule]).length(), 0)
}

///|
test "type audit reports the actual and expected kinds" {
  let value = @configscope.ConfigValue::object(
    Map([("port", @configscope.ConfigValue::string("8080"))]),
  )
  let issue = value
    .audit([
      @configscope.ConfigAuditRule::type_is(
        @configscope.parse_path("port").unwrap(),
        Number,
      ),
    ])
    .get(0)
    .unwrap()
  assert_eq(issue.path().to_string(), "port")
  assert_eq(issue.kind(), TypeMismatch)
  assert_eq(issue.expected_kind(), Some(Number))
  assert_eq(issue.actual_kind(), Some(String))
  assert_eq(issue.kind().to_string(), "type_mismatch")
  assert_eq(
    issue.message(),
    "configuration path 'port' expected number, but found string",
  )
}

///|
test "type audit ignores missing paths" {
  let value = @configscope.ConfigValue::empty_object()
  let issues = value.audit([
    @configscope.ConfigAuditRule::type_is(
      @configscope.parse_path("server.port").unwrap(),
      Number,
    ),
    @configscope.ConfigAuditRule::required(
      @configscope.parse_path("server.port").unwrap(),
    ),
  ])
  assert_eq(issues.length(), 1)
  assert_eq(issues.get(0).unwrap().kind(), MissingRequired)
}

///|
test "type audit distinguishes null from other kinds" {
  let value = @configscope.ConfigValue::object(
    Map([("token", @configscope.ConfigValue::null())]),
  )
  let issue = value
    .audit([
      @configscope.ConfigAuditRule::type_is(
        @configscope.parse_path("token").unwrap(),
        String,
      ),
    ])
    .get(0)
    .unwrap()
  assert_eq(issue.expected_kind(), Some(String))
  assert_eq(issue.actual_kind(), Some(Null))
}
