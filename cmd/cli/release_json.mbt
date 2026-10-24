///|
fn release_json_issues(
  issues : Array[@configscope.ConfigConsumerIssue],
) -> Json {
  Json::array(
    issues.map(issue => {
      Json::object(
        Map([
          ("path", json_string(issue.path().to_string())),
          ("kind", json_string(issue.kind().to_string())),
        ]),
      )
    }),
  )
}

///|
fn release_json_entry(
  entry : @configscope.ConfigConsumerRegression,
  files : Array[ConsumerBindingFile],
  policy : ConsumerReleasePolicy,
) -> Json {
  let blockers = release_entry_blockers(entry, policy)
  let fields = Map([
    ("consumer", json_string(entry.consumer())),
    ("version", json_string(entry.version())),
    ("baseline_id", json_string(entry.baseline_id())),
    ("contract", Json::null()),
    ("baseline", Json::null()),
    ("candidate_accepted", Json::boolean(entry.passes())),
    ("release_allowed", Json::boolean(blockers.is_empty())),
    ("introduced", release_json_issues(entry.introduced())),
    ("persistent", release_json_issues(entry.persistent())),
    ("resolved", release_json_issues(entry.resolved())),
    ("effective_comparable", Json::boolean(entry.effective_comparable())),
    (
      "effective_values_preserved",
      if entry.effective_comparable() {
        Json::boolean(entry.preserves_effective_values())
      } else {
        Json::null()
      },
    ),
    (
      "effective_changes",
      Json::array(
        entry
        .effective_changes()
        .map(change => {
          Json::object(
            Map([
              ("path", json_string(change.path().to_string())),
              ("before", json_string(effective_source_label(change.before()))),
              ("after", json_string(effective_source_label(change.after()))),
              ("value_changed", Json::boolean(change.value_changed())),
            ]),
          )
        }),
      ),
    ),
    (
      "blockers",
      Json::array(
        blockers.map(blocker => {
          let (reason, path) = blocker
          Json::object(
            Map([
              ("reason", json_string(reason)),
              (
                "path",
                match path {
                  Some(path) => json_string(path.to_string())
                  None => Json::null()
                },
              ),
            ]),
          )
        }),
      ),
    ),
  ])
  for file in files {
    if file.consumer == entry.consumer() && file.version == entry.version() {
      fields["contract"] = json_string(file.contract)
      fields["baseline"] = json_string(file.baseline)
    }
  }
  Json::object(fields)
}

///|
/// Computed denials have the same JSON shape as allowed decisions. Invalid
/// arguments/files/manifests never masquerade as a completed release report.
fn render_json_consumer_release(
  manifest : String,
  candidate : String,
  report : @configscope.ConfigConsumerReleaseReport,
  files : Array[ConsumerBindingFile],
  policy : ConsumerReleasePolicy,
) -> String {
  let entries = report.entries()
  let allowed = entries
    .filter(entry => release_entry_blockers(entry, policy).is_empty())
    .length()
  let passed = consumer_release_allowed(report, policy)
  Json::object(
    Map([
      ("kind", json_string("consumer_release_report")),
      ("schema_version", json_int(1)),
      ("scope", json_string("declared_consumer_versions")),
      ("manifest", json_string(manifest)),
      ("candidate", json_string(candidate)),
      ("policy", json_string(release_policy_label(policy))),
      ("candidate_accepted", Json::boolean(report.passes())),
      ("passed", Json::boolean(passed)),
      ("decision", json_string(if passed { "allowed" } else { "blocked" })),
      (
        "summary",
        Json::object(
          Map([
            ("allowed", json_int(allowed)),
            ("blocked", json_int(entries.length() - allowed)),
            ("total", json_int(entries.length())),
          ]),
        ),
      ),
      (
        "consumers",
        Json::array(
          entries.map(entry => release_json_entry(entry, files, policy)),
        ),
      ),
    ]),
  ).stringify()
}
