///|
/// Classification of a SINGLE declared path, not whole-contract inclusion.
pub(all) enum ConfigContractEvolutionImpact {
  Equivalent
  Tightened
  Relaxed
  Incomparable
  Unknown
} derive(Eq, Debug)

///|
pub extend ConfigContractEvolutionImpact with Eq::{not_equal, equal}

///|
pub extend ConfigContractEvolutionImpact with Debug::{to_repr}

///|
/// Value-free diagnostic. Reason is a stable code, never a configuration value.
pub struct ConfigContractEvolutionChange {
  path : ConfigPath
  impact : ConfigContractEvolutionImpact
  reason : String
}

///|
pub fn ConfigContractEvolutionChange::path(
  self : ConfigContractEvolutionChange,
) -> ConfigPath {
  self.path
}

///|
pub fn ConfigContractEvolutionChange::impact(
  self : ConfigContractEvolutionChange,
) -> ConfigContractEvolutionImpact {
  self.impact
}

///|
pub fn ConfigContractEvolutionChange::reason(
  self : ConfigContractEvolutionChange,
) -> String {
  self.reason
}

///|
fn evolution_subset_impact(
  old_in_new : Bool,
  new_in_old : Bool,
) -> ConfigContractEvolutionImpact {
  match (old_in_new, new_in_old) {
    (true, true) => Equivalent
    (false, true) => Tightened
    (true, false) => Relaxed
    (false, false) => Incomparable
  }
}

///|
fn evolution_lower_included(inner : Double?, outer : Double?) -> Bool {
  match (inner, outer) {
    (_, None) => true
    (None, Some(_)) => false
    (Some(a), Some(b)) => a >= b
  }
}

///|
fn evolution_upper_included(inner : Double?, outer : Double?) -> Bool {
  match (inner, outer) {
    (_, None) => true
    (None, Some(_)) => false
    (Some(a), Some(b)) => a <= b
  }
}

///|
fn evolution_path_overlap(a : ConfigPath, b : ConfigPath) -> Bool {
  let limit = if a.length() < b.length() { a.length() } else { b.length() }
  for index in 0..<limit {
    if a.segment(index) != b.segment(index) {
      return false
    }
  }
  a.length() != b.length()
}

///|
fn evolution_rule_change(
  old : ConfigConsumerRule,
  new : ConfigConsumerRule,
) -> (ConfigContractEvolutionImpact, String) {
  if old.when is Some(_) || new.when is Some(_) {
    return (Unknown, "conditional_rule")
  }
  if old.default_value != new.default_value {
    return (Unknown, "default_changed")
  }
  let required_changed = old.required != new.required
  let allowed_changed = old.allowed_values != new.allowed_values
  let bounds_changed = old.minimum != new.minimum || old.maximum != new.maximum
  if old.expected_kind != new.expected_kind || old.integer != new.integer {
    return (Unknown, "type_or_integer_changed")
  }
  let dimensions = (if required_changed { 1 } else { 0 }) +
    (if allowed_changed { 1 } else { 0 }) +
    (if bounds_changed { 1 } else { 0 })
  if dimensions != 1 {
    return (Unknown, "combined_constraints")
  }
  if required_changed {
    if old.default_value is Some(_) {
      return (Equivalent, "required_with_default")
    }
    return (if new.required { Tightened } else { Relaxed }, "required")
  }
  if allowed_changed {
    match (old.allowed_values, new.allowed_values) {
      (Some(a), Some(b)) =>
        return (
          evolution_subset_impact(
            a.all(v => b.contains(v)),
            b.all(v => a.contains(v)),
          ),
          "allowed_values",
        )
      _ => return (Unknown, "unbounded_allowed_values")
    }
  }
  // Bounds only exist on explicit number rules. Integer intervals are compared
  // after rounding inward, not by literal endpoint movement.
  let old_min = old.minimum.map(v => if old.integer { v.ceil() } else { v })
  let new_min = new.minimum.map(v => if new.integer { v.ceil() } else { v })
  let old_max = old.maximum.map(v => if old.integer { v.floor() } else { v })
  let new_max = new.maximum.map(v => if new.integer { v.floor() } else { v })
  if old.allowed_values is Some(_) {
    // Explicit enum values were validated against each interval at parse time;
    // changing bounds cannot remove any value from the unchanged allowed set.
    return (Equivalent, "bounds_with_allowed_values")
  }
  (
    evolution_subset_impact(
      evolution_lower_included(old_min, new_min) &&
      evolution_upper_included(old_max, new_max),
      evolution_lower_included(new_min, old_min) &&
      evolution_upper_included(new_max, old_max),
    ),
    "numeric_bounds",
  )
}

///|
/// Describe syntactically changed rules in lexical path order. Tightened means
/// the new rule accepts a strict subset of the old rule's inputs at this path;
/// Relaxed means a strict superset. Incomparable means neither includes the other.
/// Conditions, overlapping paths and unsupported combinations remain Unknown.
/// This is not a release gate or proof of whole-contract compatibility.
pub fn ConfigConsumerContract::evolution_to(
  self : ConfigConsumerContract,
  later : ConfigConsumerContract,
) -> Array[ConfigContractEvolutionChange] {
  let before : Map[String, ConfigConsumerRule] = Map([])
  let after : Map[String, ConfigConsumerRule] = Map([])
  for rule in self.rules {
    before[rule.path.to_string()] = rule
  }
  for rule in later.rules {
    after[rule.path.to_string()] = rule
  }
  let paths : Map[String, ConfigPath] = Map([])
  for rule in self.rules {
    paths[rule.path.to_string()] = rule.path
  }
  for rule in later.rules {
    paths[rule.path.to_string()] = rule.path
  }
  let changes : Array[ConfigContractEvolutionChange] = []
  for key, path in paths {
    let old = before.get(key)
    let new = after.get(key)
    if old == new {
      continue
    }
    let mut overlapping = false
    for _, other in paths {
      if evolution_path_overlap(path, other) {
        overlapping = true
      }
    }
    let (impact, reason) = if overlapping {
      (Unknown, "overlapping_paths")
    } else {
      match (old, new) {
        (Some(a), Some(b)) => evolution_rule_change(a, b)
        (None, Some(_)) => (Unknown, "rule_added")
        (Some(_), None) => (Unknown, "rule_removed")
        _ => abort("unreachable")
      }
    }
    changes.push({ path, impact, reason, })
  }
  changes.sort_by((a, b) => {
    a.path.to_string().lexical_compare(b.path.to_string())
  })
  changes
}
