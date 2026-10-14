///|
fn auth_contract(
  default_flag : Bool,
) -> @configscope.ConfigConsumerContract raise {
  @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"auth.token\",\"required\":true,\"type\":\"string\",\"when\":{\"path\":\"auth.enabled\",\"equals\":true}},{\"path\":\"auth.enabled\",\"type\":\"boolean\",\"default\":" +
      default_flag.to_string() +
      "}]}",
    ),
  ).unwrap()
}

///|
test "conditional requirement activates only on a matching input" {
  let contract = auth_contract(false)
  for
    source in [
      "{}", "{\"auth\":{\"enabled\":false}}", "{\"auth\":{\"enabled\":false,\"token\":7}}",
      "{\"auth\":{\"enabled\":true,\"token\":\"example\"}}",
    ] {
    assert_eq(
      contract.check(@configscope.ConfigValue::parse_json(source)).length(),
      0,
    )
  }
  let issues = contract.check(
    @configscope.ConfigValue::parse_json("{\"auth\":{\"enabled\":true}}"),
  )
  assert_eq(issues.length(), 1)
  assert_eq(issues[0].path().to_string(), "auth.token")
  assert_eq(issues[0].kind(), MissingRequired)
}

///|
test "conditions use the declared unconditional default without mutating snapshots" {
  let contract = auth_contract(true)
  let candidate = @configscope.ConfigValue::parse_json("{}")
  assert_eq(contract.check(candidate)[0].kind(), MissingRequired)
  assert_eq(candidate.to_json_string(), "{}")
  assert_eq(
    contract
    .check(
      @configscope.ConfigValue::parse_json("{\"auth\":{\"token\":\"example\"}}"),
    )
    .length(),
    0,
  )
}

///|
test "malformed condition inputs fail their unconditional rule" {
  let contract = auth_contract(false)
  for
    source in [
      "{\"auth\":{\"enabled\":\"true\"}}", "{\"auth\":{\"enabled\":null}}", "{\"auth\":42}",
    ] {
    let issues = contract.check(@configscope.ConfigValue::parse_json(source))
    assert_eq(issues[0].path().to_string(), "auth.enabled")
    assert_eq(issues[0].kind(), TypeMismatch)
  }
}

///|
test "explicit null can match a condition but an absent input cannot" {
  let contract = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"input\",\"type\":\"null\"},{\"path\":\"result\",\"required\":true,\"when\":{\"path\":\"input\",\"equals\":null}}]}",
    ),
  ).unwrap()
  assert_eq(
    contract.check(@configscope.ConfigValue::parse_json("{}")).length(),
    0,
  )
  assert_eq(
    contract.check(@configscope.ConfigValue::parse_json("{\"input\":null}"))[0].kind(),
    MissingRequired,
  )
}

///|
test "condition declarations reject missing keys unknown operators and bad paths" {
  for
    condition in [
      "null", "true", "{}", "{\"path\":\"flag\"}", "{\"equals\":true}", "{\"path\":\"bad..path\",\"equals\":true}",
      "{\"path\":\"flag\",\"equals\":true,\"else\":false}",
    ] {
    let source = "{\"rules\":[{\"path\":\"flag\",\"type\":\"boolean\"},{\"path\":\"token\",\"required\":true,\"when\":" +
      condition +
      "}]}"
    assert_true(
      @configscope.ConfigConsumerContract::from_value(
        @configscope.ConfigValue::parse_json(source),
      )
      is Err(_),
    )
  }
}

///|
test "condition references reject missing inputs cycles and impossible expected values" {
  for
    source in [
      "{\"rules\":[{\"path\":\"token\",\"required\":true,\"when\":{\"path\":\"missing\",\"equals\":true}}]}",
      "{\"rules\":[{\"path\":\"a\",\"required\":true,\"when\":{\"path\":\"b\",\"equals\":true}},{\"path\":\"b\",\"required\":true,\"when\":{\"path\":\"a\",\"equals\":true}}]}",
      "{\"rules\":[{\"path\":\"flag\",\"type\":\"boolean\"},{\"path\":\"token\",\"required\":true,\"when\":{\"path\":\"flag\",\"equals\":\"true\"}}]}",
      "{\"rules\":[{\"path\":\"flag\",\"type\":\"boolean\",\"allowed_values\":[false]},{\"path\":\"token\",\"required\":true,\"when\":{\"path\":\"flag\",\"equals\":true}}]}",
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
test "active conditional rules still apply numeric constraints" {
  let contract = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"mode\",\"type\":\"number\",\"default\":1},{\"path\":\"count\",\"type\":\"number\",\"minimum\":2,\"when\":{\"path\":\"mode\",\"equals\":1}}]}",
    ),
  ).unwrap()
  assert_eq(
    contract.check(@configscope.ConfigValue::parse_json("{\"count\":1}"))[0].kind(),
    BelowMinimum,
  )
  for mode in ["1.0", "1e0"] {
    let source = "{\"mode\":" + mode + ",\"count\":1}"
    assert_eq(
      contract.check(@configscope.ConfigValue::parse_json(source))[0].kind(),
      BelowMinimum,
    )
  }
  assert_eq(
    contract
    .check(@configscope.ConfigValue::parse_json("{\"mode\":2,\"count\":1}"))
    .length(),
    0,
  )
}
