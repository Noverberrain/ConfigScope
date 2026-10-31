///|
test "evolution report escapes metadata while hiding enumeration values" {
  let before = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"mode\",\"allowed_values\":[\"SECRET_MODE_FIXTURE\",\"safe\"]}]}",
    ),
  ).unwrap()
  let after = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"mode\",\"allowed_values\":[\"safe\"]}]}",
    ),
  ).unwrap()
  let label = "旧规则\n\"quoted\"\\"
  let changes = before.evolution_to(after)
  let text = render_contract_evolution(label, "new", changes, Text)
  assert_eq(text.contains("SECRET_MODE_FIXTURE"), false)
  assert_eq(text.contains("旧规则\n"), false)
  let json = render_contract_evolution(label, "new", changes, Json)
  assert_eq(json.contains("SECRET_MODE_FIXTURE"), false)
  assert_eq(
    @configscope.ConfigValue::parse_json(json)
    .field("before_contract")
    .unwrap()
    .as_string(),
    Some(label),
  )
}

///|
test "finite-extrema equivalence is reflected in text and JSON diagnostics" {
  let old = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"n\",\"type\":\"number\",\"integer\":true}]}",
    ),
  ).unwrap()
  let new = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"n\",\"type\":\"number\",\"integer\":true,\"maximum\":1.7976931348623157e308}]}",
    ),
  ).unwrap()
  let changes = old.evolution_to(new)
  let text = render_contract_evolution("old", "new", changes, Text)
  assert_true(text.contains("[equivalent] \"n\" reason=numeric_bounds"))
  let report = @configscope.ConfigValue::parse_json(
    render_contract_evolution("old", "new", changes, Json),
  )
  assert_eq(
    report.field("summary").unwrap().field("equivalent").unwrap().as_number(),
    Some(1.0),
  )
  assert_eq(
    report.field("summary").unwrap().field("tightened").unwrap().as_number(),
    Some(0.0),
  )
  assert_eq(report.field("is_release_gate").unwrap().as_boolean(), Some(false))
}
