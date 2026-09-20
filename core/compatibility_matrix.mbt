///|
/// A named historical configuration snapshot used as a compatibility baseline.
pub struct ConfigCompatibilityBaseline {
  name : String
  value : ConfigValue
} derive(Eq, Debug)

///|
/// Create a named compatibility baseline.
pub fn ConfigCompatibilityBaseline::new(
  name : String,
  value : ConfigValue,
) -> ConfigCompatibilityBaseline {
  { name, value }
}

///|
/// Return the name associated with this baseline snapshot.
pub fn ConfigCompatibilityBaseline::name(
  self : ConfigCompatibilityBaseline,
) -> String {
  self.name
}

///|
/// One candidate-to-baseline result in a compatibility matrix.
pub struct ConfigCompatibilityMatrixEntry {
  baseline_name : String
  report : ConfigCompatibilityReport
} derive(Eq, Debug)

///|
/// Return the name of the historical baseline.
pub fn ConfigCompatibilityMatrixEntry::baseline_name(
  self : ConfigCompatibilityMatrixEntry,
) -> String {
  self.baseline_name
}

///|
/// Return the compatibility report for this baseline.
pub fn ConfigCompatibilityMatrixEntry::report(
  self : ConfigCompatibilityMatrixEntry,
) -> ConfigCompatibilityReport {
  self.report
}

///|
/// Return whether this baseline passes the selected release policy.
pub fn ConfigCompatibilityMatrixEntry::passes(
  self : ConfigCompatibilityMatrixEntry,
  policy : ConfigCompatibilityPolicy,
) -> Bool {
  self.report.passes(policy)
}

///|
/// Return the number of policy violations for this baseline.
pub fn ConfigCompatibilityMatrixEntry::violation_count(
  self : ConfigCompatibilityMatrixEntry,
  policy : ConfigCompatibilityPolicy,
) -> Int {
  self.report.violation_count(policy)
}

///|
/// The compatibility results for one candidate against multiple baselines.
pub struct ConfigCompatibilityMatrixReport {
  entries : Array[ConfigCompatibilityMatrixEntry]
} derive(Eq, Debug)

///|
/// Return one matrix entry in the original baseline order.
pub fn ConfigCompatibilityMatrixReport::entry(
  self : ConfigCompatibilityMatrixReport,
  index : Int,
) -> ConfigCompatibilityMatrixEntry? {
  self.entries.get(index)
}

///|
/// Return all matrix entries in the original baseline order.
pub fn ConfigCompatibilityMatrixReport::entries(
  self : ConfigCompatibilityMatrixReport,
) -> Array[ConfigCompatibilityMatrixEntry] {
  self.entries.copy()
}

///|
/// Return the number of baselines checked.
pub fn ConfigCompatibilityMatrixReport::baseline_count(
  self : ConfigCompatibilityMatrixReport,
) -> Int {
  self.entries.length()
}

///|
/// Return the number of baselines that pass the selected policy.
pub fn ConfigCompatibilityMatrixReport::passed_count(
  self : ConfigCompatibilityMatrixReport,
  policy : ConfigCompatibilityPolicy,
) -> Int {
  self.entries.fold(init=0, (count, entry) => {
    if entry.passes(policy) {
      count + 1
    } else {
      count
    }
  })
}

///|
/// Return the number of baselines that violate the selected policy.
pub fn ConfigCompatibilityMatrixReport::failed_count(
  self : ConfigCompatibilityMatrixReport,
  policy : ConfigCompatibilityPolicy,
) -> Int {
  self.entries.fold(init=0, (count, entry) => {
    if entry.passes(policy) {
      count
    } else {
      count + 1
    }
  })
}

///|
/// Return whether every baseline passes the selected policy.
pub fn ConfigCompatibilityMatrixReport::passes(
  self : ConfigCompatibilityMatrixReport,
  policy : ConfigCompatibilityPolicy,
) -> Bool {
  self.failed_count(policy) == 0
}

///|
/// Return a matrix with changes at the supplied exact paths removed from
/// every baseline report.
pub fn ConfigCompatibilityMatrixReport::excluding_paths(
  self : ConfigCompatibilityMatrixReport,
  paths : Array[ConfigPath],
) -> ConfigCompatibilityMatrixReport {
  let entries = self.entries.map(entry => {
    baseline_name: entry.baseline_name,
    report: entry.report.excluding_paths(paths),
  })
  { entries, }
}

///|
/// Return a matrix with changes matching exact paths or trailing `.*` subtree
/// patterns removed from every baseline report.
pub fn ConfigCompatibilityMatrixReport::excluding_path_patterns(
  self : ConfigCompatibilityMatrixReport,
  patterns : Array[ConfigPath],
) -> ConfigCompatibilityMatrixReport {
  let entries = self.entries.map(entry => {
    baseline_name: entry.baseline_name,
    report: entry.report.excluding_path_patterns(patterns),
  })
  { entries, }
}

///|
/// Compare a candidate snapshot against multiple historical baselines.
///
/// The receiver is the later candidate snapshot. Each baseline is compared
/// to it in baseline-to-candidate order, and entries retain the input order.
pub fn ConfigValue::compatibility_matrix(
  self : ConfigValue,
  baselines : Array[ConfigCompatibilityBaseline],
) -> ConfigCompatibilityMatrixReport {
  let entries = baselines.map(baseline => {
    baseline_name: baseline.name(),
    report: baseline.value.compatibility_with(self),
  })
  { entries, }
}
