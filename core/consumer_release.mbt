///|
/// A supported consumer version bound to one declared contract and historical
/// snapshot. Labels are supplied by the caller, not authenticated provenance.
pub struct ConfigConsumerBinding {
  consumer : String
  version : String
  baseline_id : String
  contract : ConfigConsumerContract
  baseline : ConfigValue
}

///|
pub fn ConfigConsumerBinding::new(
  consumer : String,
  version : String,
  baseline_id : String,
  contract : ConfigConsumerContract,
  baseline : ConfigValue,
) -> Result[ConfigConsumerBinding, String] {
  if consumer.trim().length() == 0 ||
    version.trim().length() == 0 ||
    baseline_id.trim().length() == 0 {
    return Err("consumer, version and baseline_id must not be blank")
  }
  Ok({ consumer, version, baseline_id, contract, baseline, })
}

///|
/// A comparison under the SAME contract on both snapshots. Issue identity is
/// (path, kind), not just path. Persistent issues do not imply unchanged values.
pub struct ConfigConsumerRegression {
  consumer : String
  version : String
  baseline_id : String
  introduced : Array[ConfigConsumerIssue]
  persistent : Array[ConfigConsumerIssue]
  resolved : Array[ConfigConsumerIssue]
}

///|
pub fn ConfigConsumerRegression::consumer(
  self : ConfigConsumerRegression,
) -> String {
  self.consumer
}

///|
pub fn ConfigConsumerRegression::version(
  self : ConfigConsumerRegression,
) -> String {
  self.version
}

///|
pub fn ConfigConsumerRegression::baseline_id(
  self : ConfigConsumerRegression,
) -> String {
  self.baseline_id
}

///|
pub fn ConfigConsumerRegression::introduced(
  self : ConfigConsumerRegression,
) -> Array[ConfigConsumerIssue] {
  self.introduced.copy()
}

///|
pub fn ConfigConsumerRegression::persistent(
  self : ConfigConsumerRegression,
) -> Array[ConfigConsumerIssue] {
  self.persistent.copy()
}

///|
pub fn ConfigConsumerRegression::resolved(
  self : ConfigConsumerRegression,
) -> Array[ConfigConsumerIssue] {
  self.resolved.copy()
}

///|
/// Strict candidate acceptance: historical violations are NOT grandfathered.
pub fn ConfigConsumerRegression::passes(
  self : ConfigConsumerRegression,
) -> Bool {
  self.introduced.is_empty() && self.persistent.is_empty()
}

///|
pub struct ConfigConsumerReleaseReport {
  entries : Array[ConfigConsumerRegression]
}

///|
pub fn ConfigConsumerReleaseReport::entries(
  self : ConfigConsumerReleaseReport,
) -> Array[ConfigConsumerRegression] {
  self.entries.copy()
}

///|
/// All supplied versions are supported and must accept the candidate. This
/// does not include structural gates or prove unchanged effective values.
pub fn ConfigConsumerReleaseReport::passes(
  self : ConfigConsumerReleaseReport,
) -> Bool {
  self.entries.all(entry => entry.passes())
}

///|
/// Reject empty support sets and duplicate (consumer, version) identities.
/// Results are ordered lexically by consumer then version (not semver).
/// Per-category issues retain the checker's stable path order.
pub fn ConfigConsumerReleaseReport::check(
  bindings : Array[ConfigConsumerBinding],
  candidate : ConfigValue,
) -> Result[ConfigConsumerReleaseReport, String] {
  if bindings.is_empty() {
    return Err("at least one supported consumer version is required")
  }
  let ordered = bindings.copy()
  ordered.sort_by((a, b) => {
    let order = a.consumer.lexical_compare(b.consumer)
    if order == 0 {
      a.version.lexical_compare(b.version)
    } else {
      order
    }
  })
  for index in 1..<ordered.length() {
    let before = ordered[index - 1]
    let current = ordered[index]
    if before.consumer == current.consumer && before.version == current.version {
      return Err(
        "duplicate consumer version: " +
        current.consumer +
        "@" +
        current.version,
      )
    }
  }
  let entries = ordered.map(binding => {
    let historical = binding.contract.check(binding.baseline)
    let proposed = binding.contract.check(candidate)
    let introduced = proposed.filter(issue => !historical.contains(issue))
    let persistent = proposed.filter(issue => historical.contains(issue))
    let resolved = historical.filter(issue => !proposed.contains(issue))
    ConfigConsumerRegression::{
      consumer: binding.consumer,
      version: binding.version,
      baseline_id: binding.baseline_id,
      introduced,
      persistent,
      resolved,
    }
  })
  Ok({ entries, })
}
