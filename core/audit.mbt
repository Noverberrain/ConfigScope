///|
/// A validation rule applied to a configuration value.
///
/// Rules can require a path to exist or require an existing value to have a
/// particular JSON-compatible kind.
pub(all) enum ConfigAuditRule {
  Required(ConfigPath)
  TypeIs(ConfigPath, ConfigValueKind)
} derive(Eq, Debug)

///|
/// Describes why a configuration audit reported an issue.
pub(all) enum ConfigAuditIssueKind {
  MissingRequired
  TypeMismatch
} derive(Eq, Debug)

///|
/// A single issue found while auditing a configuration value.
pub struct ConfigAuditIssue {
  path : ConfigPath
  kind : ConfigAuditIssueKind
  expected_kind : ConfigValueKind?
  actual_kind : ConfigValueKind?
} derive(Eq, Debug)

///|
/// Create a rule that requires one configuration path to be present.
pub fn ConfigAuditRule::required(path : ConfigPath) -> ConfigAuditRule {
  Required(path)
}

///|
/// Create a rule that requires an existing value to have a particular kind.
pub fn ConfigAuditRule::type_is(
  path : ConfigPath,
  expected_kind : ConfigValueKind,
) -> ConfigAuditRule {
  TypeIs(path, expected_kind)
}

///|
/// Return the path inspected by this rule.
pub fn ConfigAuditRule::path(self : ConfigAuditRule) -> ConfigPath {
  match self {
    Required(path) => path
    TypeIs(path, _) => path
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
/// Return the expected value kind for a type mismatch.
///
/// Other issue categories return `None`.
pub fn ConfigAuditIssue::expected_kind(
  self : ConfigAuditIssue,
) -> ConfigValueKind? {
  self.expected_kind
}

///|
/// Return the actual value kind for a type mismatch.
///
/// Other issue categories return `None`.
pub fn ConfigAuditIssue::actual_kind(
  self : ConfigAuditIssue,
) -> ConfigValueKind? {
  self.actual_kind
}

///|
/// Return a stable lowercase name for this audit issue category.
pub fn ConfigAuditIssueKind::to_string(self : ConfigAuditIssueKind) -> String {
  match self {
    MissingRequired => "missing_required"
    TypeMismatch => "type_mismatch"
  }
}

///|
/// Render a concise human-readable diagnostic for this audit issue.
pub fn ConfigAuditIssue::message(self : ConfigAuditIssue) -> String {
  match self.kind {
    MissingRequired =>
      "required configuration path '\{self.path.to_string()}' is missing"
    TypeMismatch => {
      let expected = self.expected_kind.unwrap().to_string()
      let actual = self.actual_kind.unwrap().to_string()
      "configuration path '\{self.path.to_string()}' expected \{expected}, but found \{actual}"
    }
  }
}

///|
/// Apply validation rules to this configuration value.
///
/// Required paths count as present even when their value is `null`. Type rules
/// only inspect paths that exist, allowing a separate required rule to control
/// missing-path diagnostics. Issues are ordered lexicographically by path so
/// diagnostics remain deterministic.
pub fn ConfigValue::audit(
  self : ConfigValue,
  rules : Array[ConfigAuditRule],
) -> Array[ConfigAuditIssue] {
  let issues : Array[ConfigAuditIssue] = []
  for rule in rules {
    match rule {
      Required(path) =>
        if self.get(path) is None {
          issues.push({
            path,
            kind: MissingRequired,
            expected_kind: None,
            actual_kind: None,
          })
        }
      TypeIs(path, expected_kind) =>
        match self.get(path) {
          Some(value) => {
            let actual_kind = value.kind()
            if actual_kind != expected_kind {
              issues.push({
                path,
                kind: TypeMismatch,
                expected_kind: Some(expected_kind),
                actual_kind: Some(actual_kind),
              })
            }
          }
          None => ()
        }
    }
  }
  issues.sort_by((left, right) => {
    left.path.to_string().lexical_compare(right.path.to_string())
  })
  issues
}
