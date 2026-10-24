///|
fn release_policy_label(policy : ConsumerReleasePolicy) -> String {
  match policy {
    Accept => "accept"
    PreserveEffective => "preserve-effective"
  }
}

///|
/// Shared by rendering and exit decision, so explanations cannot drift from
/// the gate. No numeric, credential or other configuration values are emitted.
fn release_entry_blockers(
  entry : @configscope.ConfigConsumerRegression,
  policy : ConsumerReleasePolicy,
) -> Array[(String, @configscope.ConfigPath?)] {
  let blockers : Array[(String, @configscope.ConfigPath?)] = []
  for issue in entry.introduced() {
    blockers.push(("candidate_" + issue.kind().to_string(), Some(issue.path())))
  }
  for issue in entry.persistent() {
    blockers.push(("candidate_" + issue.kind().to_string(), Some(issue.path())))
  }
  match policy {
    Accept => ()
    PreserveEffective =>
      if !entry.effective_comparable() {
        blockers.push(("effective_incomparable", None))
      } else {
        for change in entry.effective_changes() {
          if change.value_changed() {
            blockers.push(("effective_value_changed", Some(change.path())))
          }
        }
      }
  }
  blockers
}

///|
fn consumer_release_allowed(
  report : @configscope.ConfigConsumerReleaseReport,
  policy : ConsumerReleasePolicy,
) -> Bool {
  report
  .entries()
  .all(entry => release_entry_blockers(entry, policy).is_empty())
}
