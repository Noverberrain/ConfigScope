///|
/// A declared expectation of a configuration consumer. Missing values may be
/// supplied by the consumer's default before type and allowed-value checks.
pub struct ConfigConsumerRule {
  path : ConfigPath
  required : Bool
  expected_kind : ConfigValueKind?
  allowed_values : Array[ConfigValue]?
  default_value : ConfigValue?
  minimum : Double?
  maximum : Double?
  integer : Bool
} derive(Eq, Debug)

///|
pub extend ConfigConsumerRule with Eq::{not_equal, equal}

///|
pub extend ConfigConsumerRule with Debug::{to_repr}

///|
pub struct ConfigConsumerContract {
  rules : Array[ConfigConsumerRule]
} derive(Eq, Debug)

///|
pub extend ConfigConsumerContract with Eq::{not_equal, equal}

///|
pub extend ConfigConsumerContract with Debug::{to_repr}

///|
pub(all) enum ConfigConsumerIssueKind {
  MissingRequired
  TypeMismatch
  DisallowedValue
  BelowMinimum
  AboveMaximum
  NotInteger
  NonFiniteNumber
} derive(Eq, Debug)

///|
pub extend ConfigConsumerIssueKind with Eq::{not_equal, equal}

///|
pub extend ConfigConsumerIssueKind with Debug::{to_repr}

///|
pub struct ConfigConsumerIssue {
  path : ConfigPath
  kind : ConfigConsumerIssueKind
} derive(Eq, Debug)

///|
pub extend ConfigConsumerIssue with Eq::{not_equal, equal}

///|
pub extend ConfigConsumerIssue with Debug::{to_repr}

///|
pub fn ConfigConsumerIssue::path(self : ConfigConsumerIssue) -> ConfigPath {
  self.path
}

///|
pub fn ConfigConsumerIssue::kind(
  self : ConfigConsumerIssue,
) -> ConfigConsumerIssueKind {
  self.kind
}

///|
pub fn ConfigConsumerIssueKind::to_string(
  self : ConfigConsumerIssueKind,
) -> String {
  match self {
    MissingRequired => "missing_required"
    TypeMismatch => "type_mismatch"
    DisallowedValue => "disallowed_value"
    BelowMinimum => "below_minimum"
    AboveMaximum => "above_maximum"
    NotInteger => "not_integer"
    NonFiniteNumber => "non_finite_number"
  }
}

///|
/// Parse a consumer declaration: {"rules":[{"path":"server.port",
/// "required":true,"type":"number","allowed_values":[8080],"default":8080}]}.
/// Only declared constraints are checked; unknown rule fields are rejected so
/// misspellings cannot silently weaken the release gate.
pub fn ConfigConsumerContract::from_value(
  source : ConfigValue,
) -> Result[ConfigConsumerContract, String] {
  if source.kind() != Object {
    return Err("consumer contract must be an object")
  }
  let rules_value = match source.field("rules") {
    Some(value) if value.kind() == Array => value
    _ => return Err("consumer contract requires an array 'rules'")
  }
  if rules_value.length().unwrap() == 0 {
    return Err("consumer contract 'rules' must not be empty")
  }
  let root_fields = match source.raw {
    Object(fields) => fields
    _ => abort("unreachable")
  }
  for key in root_fields.keys() {
    if key != "rules" {
      return Err("unknown consumer contract field '" + key + "'")
    }
  }
  let rules : Array[ConfigConsumerRule] = []
  let seen : Map[String, Bool] = Map([])
  for index in 0..<rules_value.length().unwrap() {
    let value = rules_value.element(index).unwrap()
    if value.kind() != Object {
      return Err("consumer rule must be an object")
    }
    let path_text = match value.field("path") {
      Some(path) =>
        match path.as_string() {
          Some(text) => text
          None => return Err("consumer rule 'path' must be a string")
        }
      None => return Err("consumer rule is missing 'path'")
    }
    let path = match parse_path(path_text) {
      Ok(path) => path
      Err(_) => return Err("invalid consumer rule path '" + path_text + "'")
    }
    if seen.contains(path_text) {
      return Err("duplicate consumer rule path '" + path_text + "'")
    }
    seen[path_text] = true
    let required = match value.field("required") {
      None => false
      Some(flag) =>
        match flag.as_boolean() {
          Some(flag) => flag
          None => return Err("consumer rule 'required' must be boolean")
        }
    }
    let expected_kind = match value.field("type") {
      None => None
      Some(kind) =>
        match kind.as_string() {
          Some("null") => Some(Null)
          Some("boolean") => Some(Boolean)
          Some("number") => Some(Number)
          Some("string") => Some(String)
          Some("array") => Some(Array)
          Some("object") => Some(Object)
          _ => return Err("consumer rule 'type' is invalid")
        }
    }
    let allowed_values = match value.field("allowed_values") {
      None => None
      Some(values) => {
        if values.kind() != Array || values.length().unwrap() == 0 {
          return Err("consumer rule 'allowed_values' must be a nonempty array")
        }
        let items : Array[ConfigValue] = []
        for item in 0..<values.length().unwrap() {
          let item_value = values.element(item).unwrap()
          match expected_kind {
            Some(kind) if item_value.kind() != kind =>
              return Err(
                "consumer allowed value has a different type at '" +
                path_text +
                "'",
              )
            _ => ()
          }
          items.push(item_value)
        }
        Some(items)
      }
    }
    let default_value = value.field("default")
    let minimum = match parse_consumer_bound(value, "minimum", path_text) {
      Ok(bound) => bound
      Err(error) => return Err(error)
    }
    let maximum = match parse_consumer_bound(value, "maximum", path_text) {
      Ok(bound) => bound
      Err(error) => return Err(error)
    }
    let integer = match value.field("integer") {
      None => false
      Some(flag) =>
        match flag.as_boolean() {
          Some(flag) => flag
          None => return Err("consumer rule 'integer' must be boolean")
        }
    }
    if (
        minimum is Some(_) ||
        maximum is Some(_) ||
        value.contains_field("integer")
      ) &&
      expected_kind != Some(Number) {
      return Err(
        "numeric consumer constraints require type 'number' at '" +
        path_text +
        "'",
      )
    }
    match (minimum, maximum) {
      (Some(lower), Some(upper)) => {
        if lower > upper {
          return Err("consumer minimum exceeds maximum at '" + path_text + "'")
        }
        if integer && lower.ceil() > upper.floor() {
          return Err(
            "consumer numeric interval contains no integer at '" +
            path_text +
            "'",
          )
        }
      }
      _ => ()
    }
    if !required && expected_kind is None && allowed_values is None {
      return Err("consumer rule at '" + path_text + "' has no constraint")
    }
    let fields = match value.raw {
      Object(fields) => fields
      _ => abort("unreachable")
    }
    for key in fields.keys() {
      if key != "path" &&
        key != "required" &&
        key != "type" &&
        key != "allowed_values" &&
        key != "default" &&
        key != "minimum" &&
        key != "maximum" &&
        key != "integer" {
        return Err("unknown consumer rule field '" + key + "'")
      }
    }
    let rule = {
      path,
      required,
      expected_kind,
      allowed_values,
      default_value,
      minimum,
      maximum,
      integer,
    }
    match allowed_values {
      Some(values) =>
        for allowed in values {
          if consumer_numeric_violation(rule, allowed) is Some(_) {
            return Err(
              "consumer allowed value violates numeric constraints at '" +
              path_text +
              "'",
            )
          }
        }
      None => ()
    }
    match default_value {
      Some(default) =>
        if consumer_violation(rule, default) is Some(_) {
          return Err(
            "consumer rule default violates constraints at '" + path_text + "'",
          )
        }
      None => ()
    }
    rules.push(rule)
  }
  Ok({ rules, })
}

///|
fn consumer_violation(
  rule : ConfigConsumerRule,
  value : ConfigValue,
) -> ConfigConsumerIssueKind? {
  match rule.expected_kind {
    Some(kind) if value.kind() != kind => return Some(TypeMismatch)
    _ => ()
  }
  match consumer_numeric_violation(rule, value) {
    Some(issue) => return Some(issue)
    None => ()
  }
  match rule.allowed_values {
    Some(values) => {
      for allowed in values {
        if allowed == value {
          return None
        }
      }
      Some(DisallowedValue)
    }
    None => None
  }
}

///|
/// A default cannot hide a non-object ancestor of the requested path.
fn consumer_parent_is_invalid(
  candidate : ConfigValue,
  path : ConfigPath,
) -> Bool {
  let mut current = candidate
  for index in 0..<(path.length() - 1) {
    if current.kind() != Object {
      return true
    }
    match current.field(path.segment(index).unwrap()) {
      Some(next) => current = next
      None => return false
    }
  }
  current.kind() != Object
}

///|
/// Return violations of the *declared* consumer expectations. A pass does
/// not prove compatibility with undeclared application behavior.
pub fn ConfigConsumerContract::check(
  self : ConfigConsumerContract,
  candidate : ConfigValue,
) -> Array[ConfigConsumerIssue] {
  let issues : Array[ConfigConsumerIssue] = []
  for rule in self.rules {
    if consumer_parent_is_invalid(candidate, rule.path) {
      issues.push({ path: rule.path, kind: TypeMismatch, })
      continue
    }
    let selected = match candidate.get(rule.path) {
      Some(value) => Some(value)
      None => rule.default_value
    }
    match selected {
      None =>
        if rule.required {
          issues.push({ path: rule.path, kind: MissingRequired, })
        }
      Some(value) =>
        match consumer_violation(rule, value) {
          Some(kind) => issues.push({ path: rule.path, kind, })
          None => ()
        }
    }
  }
  issues.sort_by((left, right) => {
    left.path.to_string().lexical_compare(right.path.to_string())
  })
  issues
}
