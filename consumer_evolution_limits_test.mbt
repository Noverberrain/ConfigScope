///|
fn limit_contract(fields : String) -> @configscope.ConfigConsumerContract raise {
  evolution_contract("{\"path\":\"n\",\"type\":\"number\"" + fields + "}")
}

///|
fn assert_limit_equivalent(
  old : @configscope.ConfigConsumerContract,
  new : @configscope.ConfigConsumerContract,
) -> Unit raise {
  for (before, after) in [(old, new), (new, old)] {
    let changes = before.evolution_to(after)
    assert_eq(changes.length(), 1)
    assert_eq(changes[0].impact(), Equivalent)
    assert_eq(changes[0].reason(), "numeric_bounds")
  }
}

///|
test "explicit finite extrema do not narrow an already finite integer domain" {
  let unbounded = limit_contract(",\"integer\":true")
  for
    fields in [
      ",\"integer\":true,\"maximum\":1.7976931348623157e308", ",\"integer\":true,\"minimum\":-1.7976931348623157e308",
      ",\"integer\":true,\"minimum\":-1.7976931348623157e308,\"maximum\":1.7976931348623157e308",
    ] {
    assert_limit_equivalent(unbounded, limit_contract(fields))
  }
}

///|
test "one-sided real bounds already exclude non-finite values on both sides" {
  assert_limit_equivalent(
    limit_contract(",\"minimum\":0"),
    limit_contract(",\"minimum\":0,\"maximum\":1.7976931348623157e308"),
  )
  assert_limit_equivalent(
    limit_contract(",\"maximum\":0"),
    limit_contract(",\"maximum\":0,\"minimum\":-1.7976931348623157e308"),
  )
}

///|
test "finite-domain normalization still detects real narrowing and widening" {
  let old = limit_contract(",\"integer\":true")
  let new = limit_contract(",\"integer\":true,\"maximum\":1e308")
  assert_eq(old.evolution_to(new)[0].impact(), Tightened)
  assert_eq(new.evolution_to(old)[0].impact(), Relaxed)
  let witness = @configscope.ConfigValue::object(
    Map([("n", @configscope.ConfigValue::number(1.7976931348623157e308))]),
  )
  assert_eq(old.check(witness).length(), 0)
  assert_eq(new.check(witness)[0].kind(), AboveMaximum)
}

///|
test "unconstrained real numbers keep their distinct non-finite admission" {
  let old = limit_contract("")
  let new = limit_contract(
    ",\"minimum\":-1.7976931348623157e308,\"maximum\":1.7976931348623157e308",
  )
  assert_eq(old.evolution_to(new)[0].impact(), Tightened)
  assert_eq(new.evolution_to(old)[0].impact(), Relaxed)
  let zero = 0.0
  for number in [zero / zero, 1.0 / zero, -1.0 / zero] {
    let witness = @configscope.ConfigValue::object(
      Map([("n", @configscope.ConfigValue::number(number))]),
    )
    assert_eq(old.check(witness).length(), 0)
    assert_eq(new.check(witness)[0].kind(), NonFiniteNumber)
  }
}

///|
test "equivalent integer limits agree with admission including infinities and NaN" {
  let old = limit_contract(",\"integer\":true")
  let new = limit_contract(
    ",\"integer\":true,\"minimum\":-1.7976931348623157e308,\"maximum\":1.7976931348623157e308",
  )
  let zero = 0.0
  for
    number in [
      0.0,
      -0.0,
      0.5,
      1.0,
      -1.0,
      1.7976931348623157e308,
      -1.7976931348623157e308,
      zero / zero,
      1.0 / zero,
      -1.0 / zero,
    ] {
    let value = @configscope.ConfigValue::object(
      Map([("n", @configscope.ConfigValue::number(number))]),
    )
    assert_eq(old.check(value), new.check(value))
  }
  assert_limit_equivalent(old, new)
}
