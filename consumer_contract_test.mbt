///|
test "consumer rules catch illegal value even when snapshot gate passes" {
  let before = @configscope.ConfigValue::parse_json(
    "{\"server\":{\"port\":8080}}",
  )
  let after = @configscope.ConfigValue::parse_json(
    "{\"server\":{\"port\":9999}}",
  )
  assert_true(before.compatibility_with(after).is_compatible())
  let source = @configscope.ConfigValue::parse_json(
    "{\"rules\":[{\"path\":\"server.port\",\"required\":true,\"type\":\"number\",\"allowed_values\":[8080,9090]}]}",
  )
  let contract = @configscope.ConfigConsumerContract::from_value(source).unwrap()
  let issues = contract.check(after)
  assert_eq(issues.length(), 1)
  assert_eq(issues[0].path().to_string(), "server.port")
  assert_eq(issues[0].kind().to_string(), "disallowed_value")
}

///|
test "consumer declarations reject contradictory and ineffective rules" {
  for
    source in [
      "{\"rules\":[{\"path\":\"port\",\"type\":\"number\",\"allowed_values\":[\"8080\"]}]}",
      "{\"rules\":[{\"path\":\"port\",\"default\":8080}]}", "{\"rules\":[{\"path\":\"port\",\"required\":true},{\"path\":\"port\",\"type\":\"number\"}]}",
      "{\"rules\":[{\"path\":\"port\",\"type\":\"number\"}],\"unknown\":true}",
    ] {
    assert_true(
      @configscope.ConfigConsumerContract::from_value(
        @configscope.ConfigValue::parse_json(source),
      )
      is Err(_),
    )
  }
}

///|
test "consumer defaults never replace explicit null or mutate the candidate" {
  let contract = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"port\",\"type\":\"number\",\"default\":8080}]}",
    ),
  ).unwrap()
  let absent = @configscope.ConfigValue::parse_json("{}")
  assert_eq(contract.check(absent).length(), 0)
  assert_eq(absent.to_json_string(), "{}")
  let explicit_null = @configscope.ConfigValue::parse_json("{\"port\":null}")
  assert_eq(contract.check(explicit_null)[0].kind(), TypeMismatch)
}

///|
test "consumer optional fields and diagnostics preserve declared semantics" {
  let contract = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"z\",\"required\":true},{\"path\":\"a\",\"required\":true},{\"path\":\"optional\",\"type\":\"string\"}]}",
    ),
  ).unwrap()
  let issues = contract.check(@configscope.ConfigValue::parse_json("{}"))
  assert_eq(issues.length(), 2)
  assert_eq(issues[0].path().to_string(), "a")
  assert_eq(issues[1].path().to_string(), "z")
  assert_eq(issues[0].kind(), MissingRequired)
}

///|
test "consumer required path fails even without snapshot changes" {
  let candidate = @configscope.ConfigValue::parse_json("{\"server\":{}}")
  assert_true(candidate.compatibility_with(candidate).is_compatible())
  let contract = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"server.port\",\"required\":true,\"type\":\"number\"}]}",
    ),
  ).unwrap()
  assert_eq(contract.check(candidate)[0].kind().to_string(), "missing_required")
}

///|
test "consumer default permits missing value but not invalid explicit value" {
  let contract = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"server.port\",\"required\":true,\"type\":\"number\",\"allowed_values\":[8080],\"default\":8080}]}",
    ),
  ).unwrap()
  assert_eq(
    contract.check(@configscope.ConfigValue::parse_json("{}")).length(),
    0,
  )
  let invalid = @configscope.ConfigValue::parse_json(
    "{\"server\":{\"port\":9090}}",
  )
  assert_eq(contract.check(invalid)[0].kind().to_string(), "disallowed_value")
  let blocked_path = @configscope.ConfigValue::parse_json("{\"server\":42}")
  assert_eq(contract.check(blocked_path)[0].kind().to_string(), "type_mismatch")
}

///|
test "consumer rule checks type and rejects invalid declarations" {
  let contract = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"server.port\",\"type\":\"number\"}]}",
    ),
  ).unwrap()
  let candidate = @configscope.ConfigValue::parse_json(
    "{\"server\":{\"port\":\"8080\"}}",
  )
  assert_eq(contract.check(candidate)[0].kind().to_string(), "type_mismatch")
  let invalid_default = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"server.port\",\"type\":\"number\",\"default\":\"8080\"}]}",
    ),
  )
  assert_true(invalid_default is Err(_))
  let typo = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"server.port\",\"requred\":true}]}",
    ),
  )
  assert_true(typo is Err(_))
  assert_true(
    @configscope.ConfigConsumerContract::from_value(
      @configscope.ConfigValue::parse_json("{\"rules\":[]}"),
    )
    is Err(_),
  )
}
