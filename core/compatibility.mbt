///|
/// Classifies the impact of a configuration change for version evolution.
///
/// This baseline classification treats added paths as compatible, changed
/// values as behavioral changes, and removed or type-changed paths as breaking
/// changes. A later policy layer can refine these defaults with schema rules.
pub(all) enum ConfigCompatibilityImpact {
  Compatible
  Behavioral
  Breaking
} derive(Eq, Debug)

///|
/// Selects which compatibility impacts should fail a release gate.
///
/// `BreakingOnly` is the default and rejects only breaking changes.
/// `NoBehavioralChanges` also rejects behavioral changes, while `NoChanges`
/// requires the two snapshots to be identical.
pub(all) enum ConfigCompatibilityPolicy {
  BreakingOnly
  NoBehavioralChanges
  NoChanges
} derive(Eq, Debug)

///|
/// A configuration difference together with its compatibility impact.
pub struct ConfigCompatibilityChange {
  difference : ConfigDiff
  impact : ConfigCompatibilityImpact
} derive(Eq, Debug)

///|
/// The compatibility result for an earlier and a later configuration value.
pub struct ConfigCompatibilityReport {
  changes : Array[ConfigCompatibilityChange]
} derive(Eq, Debug)

///|
/// Return a stable lowercase name for a compatibility impact.
pub fn ConfigCompatibilityImpact::to_string(
  self : ConfigCompatibilityImpact,
) -> String {
  match self {
    Compatible => "compatible"
    Behavioral => "behavioral"
    Breaking => "breaking"
  }
}

///|
/// Return the stable command-line name for a compatibility policy.
pub fn ConfigCompatibilityPolicy::to_string(
  self : ConfigCompatibilityPolicy,
) -> String {
  match self {
    BreakingOnly => "breaking"
    NoBehavioralChanges => "behavioral"
    NoChanges => "any"
  }
}

///|
/// Return whether an impact is allowed by this policy.
fn ConfigCompatibilityPolicy::allows(
  self : ConfigCompatibilityPolicy,
  impact : ConfigCompatibilityImpact,
) -> Bool {
  match self {
    BreakingOnly => impact != Breaking
    NoBehavioralChanges => impact == Compatible
    NoChanges => false
  }
}

///|
/// Return the path affected by this compatibility change.
pub fn ConfigCompatibilityChange::path(
  self : ConfigCompatibilityChange,
) -> ConfigPath {
  self.difference.path()
}

///|
/// Return the original difference category.
pub fn ConfigCompatibilityChange::difference_kind(
  self : ConfigCompatibilityChange,
) -> ConfigDiffKind {
  self.difference.kind()
}

///|
/// Return the compatibility impact assigned to this change.
pub fn ConfigCompatibilityChange::impact(
  self : ConfigCompatibilityChange,
) -> ConfigCompatibilityImpact {
  self.impact
}

///|
/// Return the earlier value, or `None` when the path was added.
pub fn ConfigCompatibilityChange::before(
  self : ConfigCompatibilityChange,
) -> ConfigValue? {
  self.difference.before()
}

///|
/// Return the later value, or `None` when the path was removed.
pub fn ConfigCompatibilityChange::after(
  self : ConfigCompatibilityChange,
) -> ConfigValue? {
  self.difference.after()
}

///|
/// Render a concise description of the change.
pub fn ConfigCompatibilityChange::message(
  self : ConfigCompatibilityChange,
) -> String {
  let path = self.path().to_string()
  let location = if path == "" {
    "configuration root"
  } else {
    "configuration path '\{path}'"
  }
  match self.difference_kind() {
    Added => "\{location} was added"
    Removed => "\{location} was removed"
    Changed => "\{location} changed value"
    TypeChanged => "\{location} changed type"
  }
}

///|
/// Return one change by its stable path order, or `None` when out of bounds.
pub fn ConfigCompatibilityReport::change(
  self : ConfigCompatibilityReport,
  index : Int,
) -> ConfigCompatibilityChange? {
  self.changes.get(index)
}

///|
/// Return all changes in stable path order.
pub fn ConfigCompatibilityReport::changes(
  self : ConfigCompatibilityReport,
) -> Array[ConfigCompatibilityChange] {
  self.changes.copy()
}

///|
/// Return the total number of configuration changes.
pub fn ConfigCompatibilityReport::change_count(
  self : ConfigCompatibilityReport,
) -> Int {
  self.changes.length()
}

///|
/// Return the number of compatible changes.
pub fn ConfigCompatibilityReport::compatible_count(
  self : ConfigCompatibilityReport,
) -> Int {
  self.changes.fold(init=0, (count, change) => {
    if change.impact() == Compatible {
      count + 1
    } else {
      count
    }
  })
}

///|
/// Return the number of behavioral changes.
pub fn ConfigCompatibilityReport::behavioral_count(
  self : ConfigCompatibilityReport,
) -> Int {
  self.changes.fold(init=0, (count, change) => {
    if change.impact() == Behavioral {
      count + 1
    } else {
      count
    }
  })
}

///|
/// Return the number of breaking changes.
pub fn ConfigCompatibilityReport::breaking_count(
  self : ConfigCompatibilityReport,
) -> Int {
  self.changes.fold(init=0, (count, change) => {
    if change.impact() == Breaking {
      count + 1
    } else {
      count
    }
  })
}

///|
/// Return the number of changes that violate a release policy.
pub fn ConfigCompatibilityReport::violation_count(
  self : ConfigCompatibilityReport,
  policy : ConfigCompatibilityPolicy,
) -> Int {
  self.changes.fold(init=0, (count, change) => {
    if policy.allows(change.impact()) {
      count
    } else {
      count + 1
    }
  })
}

///|
/// Return whether this report passes a release policy.
pub fn ConfigCompatibilityReport::passes(
  self : ConfigCompatibilityReport,
  policy : ConfigCompatibilityPolicy,
) -> Bool {
  self.violation_count(policy) == 0
}

///|
/// Return whether this report contains no breaking changes.
pub fn ConfigCompatibilityReport::is_compatible(
  self : ConfigCompatibilityReport,
) -> Bool {
  self.passes(BreakingOnly)
}

///|
/// Classify one value-level difference using the baseline compatibility model.
fn compatibility_impact(kind : ConfigDiffKind) -> ConfigCompatibilityImpact {
  match kind {
    Added => Compatible
    Removed => Breaking
    Changed => Behavioral
    TypeChanged => Breaking
  }
}

///|
/// Compare two configuration snapshots for version compatibility.
///
/// This API intentionally compares already materialized JSON-compatible
/// values. It does not parse configuration files or merge runtime layers.
/// Differences retain the deterministic path order of `ConfigValue::diff`.
pub fn ConfigValue::compatibility_with(
  self : ConfigValue,
  later : ConfigValue,
) -> ConfigCompatibilityReport {
  let changes = self
    .diff(later)
    .map(diff => { difference: diff, impact: compatibility_impact(diff.kind()) })
  { changes, }
}
