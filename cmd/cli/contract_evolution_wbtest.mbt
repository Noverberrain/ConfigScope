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
