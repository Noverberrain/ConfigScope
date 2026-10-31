///|
/// Numeric bounds are inclusive and must be finite JSON numbers.
fn parse_consumer_bound(
  source : ConfigValue,
  field : String,
  path : String,
) -> Result[Double?, String] {
  match source.field(field) {
    None => Ok(None)
    Some(value) =>
      match value.as_number() {
        Some(bound) if !bound.is_nan() && !bound.is_inf() => Ok(Some(bound))
        _ =>
          Err(
            "consumer '" + field + "' must be a finite number at '" + path + "'",
          )
      }
  }
}

///|
/// These constraints make validation reject every non-finite numeric value.
/// Keep evolution's domain normalization tied to this exact predicate.
fn consumer_has_numeric_constraints(rule : ConfigConsumerRule) -> Bool {
  rule.integer || rule.minimum is Some(_) || rule.maximum is Some(_)
}

///|
/// Report one stable numeric violation, before checking the allowed-value set.
/// Avoid Int conversion: valid integral Doubles can exceed the Int range.
fn consumer_numeric_violation(
  rule : ConfigConsumerRule,
  value : ConfigValue,
) -> ConfigConsumerIssueKind? {
  if !consumer_has_numeric_constraints(rule) {
    return None
  }
  let number = match value.as_number() {
    Some(number) => number
    None => return Some(TypeMismatch)
  }
  if number.is_nan() || number.is_inf() {
    return Some(NonFiniteNumber)
  }
  if rule.integer && number.floor() != number {
    return Some(NotInteger)
  }
  match rule.minimum {
    Some(lower) if number < lower => return Some(BelowMinimum)
    _ => ()
  }
  match rule.maximum {
    Some(upper) if number > upper => return Some(AboveMaximum)
    _ => ()
  }
  None
}
