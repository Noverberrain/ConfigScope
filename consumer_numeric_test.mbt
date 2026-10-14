///|
fn numeric_contract(
  fields : String,
) -> @configscope.ConfigConsumerContract raise {
  @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"value\",\"type\":\"number\"," + fields + "}]}",
    ),
  ).unwrap()
}

///|
test "numeric constraints include both endpoints and accept integral notation" {
  let contract = numeric_contract(
    "\"minimum\":0,\"maximum\":10,\"integer\":true",
  )
  for number in ["0", "10", "2.0", "1e1", "-0.0"] {
    let value = @configscope.ConfigValue::parse_json(
      "{\"value\":" + number + "}",
    )
    assert_eq(contract.check(value).length(), 0)
  }
}

///|
test "numeric violations distinguish bounds fractions and wrong types" {
  let contract = numeric_contract(
    "\"minimum\":0,\"maximum\":10,\"integer\":true",
  )
  for
    (number, kind) in [
      ("-1", "below_minimum"),
      ("11", "above_maximum"),
      ("3.25", "not_integer"),
      ("\"1\"", "type_mismatch"),
      ("null", "type_mismatch"),
    ] {
    let value = @configscope.ConfigValue::parse_json(
      "{\"value\":" + number + "}",
    )
    assert_eq(contract.check(value).length(), 1)
    assert_eq(contract.check(value)[0].kind().to_string(), kind)
  }
}

///|
test "one-sided bounds support fractions without an integer constraint" {
  let lower = numeric_contract("\"minimum\":0.5,\"integer\":false")
  let upper = numeric_contract("\"maximum\":0.5")
  for source in ["{\"value\":0.5}", "{\"value\":3.25}"] {
    assert_eq(
      lower.check(@configscope.ConfigValue::parse_json(source)).length(),
      0,
    )
  }
  assert_eq(
    lower.check(@configscope.ConfigValue::parse_json("{\"value\":0.4}"))[0].kind(),
    BelowMinimum,
  )
  assert_eq(
    upper
    .check(@configscope.ConfigValue::parse_json("{\"value\":-3.25}"))
    .length(),
    0,
  )
  assert_eq(
    upper.check(@configscope.ConfigValue::parse_json("{\"value\":0.6}"))[0].kind(),
    AboveMaximum,
  )
}

///|
test "integer validation does not truncate large numbers into Int" {
  let contract = numeric_contract("\"integer\":true")
  assert_eq(
    contract
    .check(@configscope.ConfigValue::parse_json("{\"value\":4294967296}"))
    .length(),
    0,
  )
  assert_eq(
    contract.check(@configscope.ConfigValue::parse_json("{}")).length(),
    0,
  )
}

///|
test "numeric defaults and allowed sets obey all declared constraints" {
  for
    fields in [
      "\"minimum\":1,\"default\":0", "\"integer\":true,\"default\":1.5", "\"maximum\":10,\"allowed_values\":[11]",
      "\"integer\":true,\"allowed_values\":[1.5]",
    ] {
    assert_true(
      @configscope.ConfigConsumerContract::from_value(
        @configscope.ConfigValue::parse_json(
          "{\"rules\":[{\"path\":\"value\",\"type\":\"number\"," +
          fields +
          "}]}",
        ),
      )
      is Err(_),
    )
  }
  let contract = numeric_contract(
    "\"minimum\":1,\"maximum\":4,\"integer\":true,\"default\":4",
  )
  assert_eq(
    contract.check(@configscope.ConfigValue::parse_json("{}")).length(),
    0,
  )
}

///|
test "numeric declarations reject invalid fields and impossible intervals" {
  for
    fields in [
      "\"minimum\":\"1\"", "\"maximum\":null", "\"integer\":\"true\"", "\"minimum\":5,\"maximum\":4",
      "\"minimum\":0.2,\"maximum\":0.8,\"integer\":true",
    ] {
    assert_true(
      @configscope.ConfigConsumerContract::from_value(
        @configscope.ConfigValue::parse_json(
          "{\"rules\":[{\"path\":\"value\",\"type\":\"number\"," +
          fields +
          "}]}",
        ),
      )
      is Err(_),
    )
  }
  for
    source in [
      "{\"rules\":[{\"path\":\"value\",\"minimum\":1}]}", "{\"rules\":[{\"path\":\"value\",\"type\":\"string\",\"integer\":true}]}",
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
test "non-finite numbers cannot bypass numeric constraints" {
  let zero = 0.0
  let contract = numeric_contract("\"minimum\":0,\"integer\":true")
  for number in [zero / zero, 1.0 / zero, -1.0 / zero] {
    let value = @configscope.ConfigValue::object(
      Map([("value", @configscope.ConfigValue::number(number))]),
    )
    assert_eq(contract.check(value)[0].kind(), NonFiniteNumber)
    let source = @configscope.ConfigValue::object(
      Map([
        (
          "rules",
          @configscope.ConfigValue::array([
            @configscope.ConfigValue::object(
              Map([
                ("path", @configscope.ConfigValue::string("value")),
                ("type", @configscope.ConfigValue::string("number")),
                ("minimum", @configscope.ConfigValue::number(number)),
              ]),
            ),
          ]),
        ),
      ]),
    )
    assert_true(
      @configscope.ConfigConsumerContract::from_value(source) is Err(_),
    )
  }
}
