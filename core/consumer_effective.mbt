///|
/// Source of a declared rule's effective selection. No configuration values
/// are exposed in the public change report.
pub(all) enum ConfigEffectiveSource {
  Inactive
  Missing
  Explicit
  Default
} derive(Eq, Debug)

///|
pub extend ConfigEffectiveSource with Eq::{not_equal, equal}

///|
pub extend ConfigEffectiveSource with Debug::{to_repr}

///|
pub struct ConfigEffectiveChange {
  path : ConfigPath
  before : ConfigEffectiveSource
  after : ConfigEffectiveSource
  value_changed : Bool
}

///|
pub fn ConfigEffectiveChange::path(self : ConfigEffectiveChange) -> ConfigPath {
  self.path
}

///|
pub fn ConfigEffectiveChange::before(
  self : ConfigEffectiveChange,
) -> ConfigEffectiveSource {
  self.before
}

///|
pub fn ConfigEffectiveChange::after(
  self : ConfigEffectiveChange,
) -> ConfigEffectiveSource {
  self.after
}

///|
/// True for unequal selected values or transitions between inactive, missing
/// and present states. Equal explicit/default values are provenance-only.
pub fn ConfigEffectiveChange::value_changed(
  self : ConfigEffectiveChange,
) -> Bool {
  self.value_changed
}

///|
fn consumer_effective_selection(
  rule : ConfigConsumerRule,
  snapshot : ConfigValue,
  inputs : Map[String, ConfigConsumerRule],
) -> (ConfigEffectiveSource, ConfigValue?) {
  if !consumer_condition_matches(rule, snapshot, inputs) {
    return (Inactive, None)
  }
  match snapshot.get(rule.path) {
    Some(value) => (Explicit, Some(value))
    None =>
      match rule.default_value {
        Some(value) => (Default, Some(value))
        None => (Missing, None)
      }
  }
}

///|
/// Called only after BOTH snapshots pass the bound contract. No implicit
/// normalization, mutation, application execution or undeclared-path analysis.
fn consumer_effective_changes(
  contract : ConfigConsumerContract,
  historical : ConfigValue,
  candidate : ConfigValue,
) -> Array[ConfigEffectiveChange] {
  let inputs = consumer_unconditional_rules(contract.rules)
  let changes : Array[ConfigEffectiveChange] = []
  for rule in contract.rules {
    let (before, old_value) = consumer_effective_selection(
      rule, historical, inputs,
    )
    let (after, new_value) = consumer_effective_selection(
      rule, candidate, inputs,
    )
    let value_changed = if old_value is Some(_) && new_value is Some(_) {
      old_value != new_value
    } else {
      before != after
    }
    if before != after || value_changed {
      changes.push({ path: rule.path, before, after, value_changed, })
    }
  }
  changes.sort_by((a, b) => {
    a.path.to_string().lexical_compare(b.path.to_string())
  })
  changes
}
