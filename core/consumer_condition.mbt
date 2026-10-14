///|
/// `when` activates the entire rule on equality with a declared input field.
fn parse_consumer_condition(
  source : ConfigValue,
) -> Result[(ConfigPath, ConfigValue)?, String] {
  let value = match source.field("when") {
    None => return Ok(None)
    Some(value) if value.kind() == Object => value
    _ => return Err("consumer 'when' must be an object")
  }
  let path = match value.field("path") {
    Some(path) =>
      match path.as_string() {
        Some(text) =>
          match parse_path(text) {
            Ok(path) => path
            Err(_) => return Err("invalid consumer condition path")
          }
        None => return Err("consumer condition 'path' must be a string")
      }
    None => return Err("consumer condition is missing 'path'")
  }
  let expected = match value.field("equals") {
    Some(expected) => expected
    None => return Err("consumer condition is missing 'equals'")
  }
  let fields = match value.raw {
    Object(fields) => fields
    _ => abort("unreachable")
  }
  for key in fields.keys() {
    if key != "path" && key != "equals" {
      return Err("unknown consumer condition field '" + key + "'")
    }
  }
  Ok(Some((path, expected)))
}

///|
fn consumer_unconditional_rules(
  rules : Array[ConfigConsumerRule],
) -> Map[String, ConfigConsumerRule] {
  let inputs : Map[String, ConfigConsumerRule] = Map([])
  for rule in rules {
    if rule.when is None {
      inputs[rule.path.to_string()] = rule
    }
  }
  inputs
}

///|
/// Input rules must be unconditional, avoiding cycles and ambiguous defaults.
fn validate_consumer_conditions(
  rules : Array[ConfigConsumerRule],
) -> Result[Unit, String] {
  let inputs = consumer_unconditional_rules(rules)
  for rule in rules {
    match rule.when {
      None => ()
      Some((path, expected)) => {
        let input = match inputs.get(path.to_string()) {
          Some(input) => input
          None =>
            return Err(
              "consumer condition must reference an unconditional rule at '" +
              path.to_string() +
              "'",
            )
        }
        if consumer_violation(input, expected) is Some(_) {
          return Err(
            "consumer condition value violates its input rule at '" +
            path.to_string() +
            "'",
          )
        }
      }
    }
  }
  Ok(())
}

///|
fn consumer_condition_matches(
  rule : ConfigConsumerRule,
  candidate : ConfigValue,
  inputs : Map[String, ConfigConsumerRule],
) -> Bool {
  match rule.when {
    None => true
    Some((path, expected)) => {
      let input = inputs.get(path.to_string()).unwrap()
      let actual = match candidate.get(path) {
        Some(value) => Some(value)
        None => input.default_value
      }
      match actual {
        Some(value) => value == expected
        None => false
      }
    }
  }
}
