///|
/// A validation rule applied to a configuration value.
///
/// The first audit milestone supports required paths. Additional rule kinds can
/// be added without changing the `ConfigValue::audit` entry point.
pub(all) enum ConfigAuditRule {
  Required(ConfigPath)
} derive(Eq, Debug)

///|
/// Describes why a configuration audit reported an issue.
pub(all) enum ConfigAuditIssueKind {
  MissingRequired
} derive(Eq, Debug)

///|
/// A single issue found while auditing a configuration value.
pub struct ConfigAuditIssue {
  path : ConfigPath
  kind : ConfigAuditIssueKind
} derive(Eq, Debug)

///|
/// Create a rule that requires one configuration path to be present.
pub fn ConfigAuditRule::required(path : ConfigPath) -> ConfigAuditRule {
  Required(path)
}

///|
/// Return the path inspected by this rule.
pub fn ConfigAuditRule::path(self : ConfigAuditRule) -> ConfigPath {
  match self {
    Required(path) => path
  }
}

///|
/// Return the path associated with this audit issue.
pub fn ConfigAuditIssue::path(self : ConfigAuditIssue) -> ConfigPath {
  self.path
}

///|
/// Return the category of this audit issue.
pub fn ConfigAuditIssue::kind(self : ConfigAuditIssue) -> ConfigAuditIssueKind {
  self.kind
}

///|
/// Return a stable lowercase name for this audit issue category.
pub fn ConfigAuditIssueKind::to_string(self : ConfigAuditIssueKind) -> String {
  match self {
    MissingRequired => "missing_required"
  }
}

///|
/// Render a concise human-readable diagnostic for this audit issue.
pub fn ConfigAuditIssue::message(self : ConfigAuditIssue) -> String {
  match self.kind {
    MissingRequired =>
      "required configuration path '\{self.path.to_string()}' is missing"
  }
}

///|
/// Apply validation rules to this configuration value.
///
/// Required paths count as present even when their value is `null`. Issues are
/// ordered lexicographically by path so diagnostics remain deterministic.
pub fn ConfigValue::audit(
  self : ConfigValue,
  rules : Array[ConfigAuditRule],
) -> Array[ConfigAuditIssue] {
  let issues : Array[ConfigAuditIssue] = []
  for rule in rules {
    match rule {
      Required(path) =>
        if self.get(path) is None {
          issues.push({ path, kind: MissingRequired })
        }
    }
  }
  issues.sort_by((left, right) => {
    left.path.to_string().lexical_compare(right.path.to_string())
  })
  issues
}
