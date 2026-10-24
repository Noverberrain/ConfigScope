///|
priv struct ConsumerBindingFile {
  consumer : String
  version : String
  baseline_id : String
  contract : String
  baseline : String
}

///|
priv enum ConsumerReleasePolicy {
  Accept
  PreserveEffective
}

///|
priv struct ConsumerReleaseManifest {
  candidate : String
  bindings : Array[ConsumerBindingFile]
  policy : ConsumerReleasePolicy
}

///|
fn release_manifest_text(
  value : @configscope.ConfigValue,
  key : String,
) -> Result[String, String] {
  match value.field(key) {
    Some(field) =>
      match field.as_string() {
        Some(text) if text.trim().length() > 0 => Ok(text)
        _ =>
          Err("release manifest field '" + key + "' must be a nonblank string")
      }
    None => Err("release manifest is missing field '" + key + "'")
  }
}

///|
/// Exact required-key counts plus required-field reads reject unknown fields
/// without exposing arbitrary input field names or values in diagnostics.
fn parse_consumer_release_manifest(
  value : @configscope.ConfigValue,
) -> Result[ConsumerReleaseManifest, String] {
  if value.kind() != Object {
    return Err("release manifest must be an object")
  }
  let expected_fields = if value.contains_field("policy") { 3 } else { 2 }
  if value.length() != Some(expected_fields) {
    return Err(
      "release manifest requires candidate, bindings and optional policy only",
    )
  }
  let policy = match value.field("policy") {
    None => Accept
    Some(field) =>
      match field.as_string() {
        Some("accept") => Accept
        Some("preserve-effective") => PreserveEffective
        _ => return Err("release policy must be accept or preserve-effective")
      }
  }
  let candidate = match release_manifest_text(value, "candidate") {
    Ok(text) => text
    Err(error) => return Err(error)
  }
  let items = match value.field("bindings") {
    Some(items) if items.kind() == Array && items.length() != Some(0) => items
    _ => return Err("release manifest bindings must be a nonempty array")
  }
  let bindings : Array[ConsumerBindingFile] = []
  for index in 0..<items.length().unwrap() {
    let item = items.element(index).unwrap()
    if item.kind() != Object || item.length() != Some(5) {
      return Err(
        "release binding requires exactly consumer, version, baseline_id, contract and baseline",
      )
    }
    let consumer = match release_manifest_text(item, "consumer") {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let version = match release_manifest_text(item, "version") {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let baseline_id = match release_manifest_text(item, "baseline_id") {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let contract = match release_manifest_text(item, "contract") {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let baseline = match release_manifest_text(item, "baseline") {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    for prior in bindings {
      if prior.consumer == consumer && prior.version == version {
        return Err("duplicate consumer version in release manifest")
      }
    }
    bindings.push({ consumer, version, baseline_id, contract, baseline, })
  }
  Ok({ candidate, bindings, policy, })
}

///|
fn release_label(text : String) -> String {
  @configscope.ConfigValue::string(text).to_json_string()
}

///|
fn effective_source_label(
  source : @configscope.ConfigEffectiveSource,
) -> String {
  match source {
    Inactive => "inactive"
    Missing => "missing"
    Explicit => "explicit"
    Default => "default"
  }
}

///|
fn render_consumer_release(
  manifest : String,
  candidate : String,
  report : @configscope.ConfigConsumerReleaseReport,
  files : Array[ConsumerBindingFile],
  policy : ConsumerReleasePolicy,
) -> String {
  let lines = [
    "release manifest: " + release_label(manifest),
    "candidate: " + release_label(candidate),
    "policy: " + release_policy_label(policy),
  ]
  for entry in report.entries() {
    lines.push(
      "consumer: " +
      release_label(entry.consumer()) +
      " version: " +
      release_label(entry.version()),
    )
    lines.push("baseline: " + release_label(entry.baseline_id()))
    for file in files {
      if file.consumer == entry.consumer() && file.version == entry.version() {
        lines.push("contract file: " + release_label(file.contract))
        lines.push("baseline file: " + release_label(file.baseline))
      }
    }
    for issue in entry.introduced() {
      lines.push(
        "  introduced: " +
        issue.kind().to_string() +
        " " +
        release_label(issue.path().to_string()),
      )
    }
    for issue in entry.persistent() {
      lines.push(
        "  persistent: " +
        issue.kind().to_string() +
        " " +
        release_label(issue.path().to_string()),
      )
    }
    for issue in entry.resolved() {
      lines.push(
        "  resolved: " +
        issue.kind().to_string() +
        " " +
        release_label(issue.path().to_string()),
      )
    }
    lines.push("  candidate accepted: " + entry.passes().to_string())
    if entry.effective_comparable() {
      for change in entry.effective_changes() {
        lines.push(
          "  effective: " +
          release_label(change.path().to_string()) +
          " " +
          effective_source_label(change.before()) +
          " -> " +
          effective_source_label(change.after()) +
          " value_changed=" +
          change.value_changed().to_string(),
        )
      }
      lines.push(
        "  effective values preserved: " +
        entry.preserves_effective_values().to_string(),
      )
    } else {
      lines.push("  effective values: incomparable (invalid snapshot)")
    }
    let blockers = release_entry_blockers(entry, policy)
    for (reason, path) in blockers {
      let suffix = match path {
        Some(path) => " " + release_label(path.to_string())
        None => ""
      }
      lines.push("  blocked: " + reason + suffix)
    }
    lines.push("  release allowed: " + blockers.is_empty().to_string())
  }
  lines.push(
    "candidate acceptance: " +
    (if report.passes() { "passed" } else { "failed" }),
  )
  lines.push(
    "release decision: " +
    (if consumer_release_allowed(report, policy) {
      "allowed"
    } else {
      "blocked"
    }),
  )
  lines.push(
    match policy {
      Accept =>
        "scope: candidate constraints only; effective changes are advisory"
      PreserveEffective =>
        "scope: candidate constraints and declared effective selections only; incomparable blocks release"
    },
  )
  lines.join("\n")
}

///|
/// All file references are relative to this manifest, never the process CWD.
/// The explicit manifest policy governs the decision; no CLI override can
/// silently weaken it. Rule evolution is not inferred. This command is read-only.
fn run_consumer_release(args : Array[String]) -> Result[String, String] {
  let manifest = args[2]
  let source = match read_config(manifest) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let plan = match parse_consumer_release_manifest(source) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let candidate = match
    read_contract_snapshot(manifest, "candidate", plan.candidate) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let bindings : Array[@configscope.ConfigConsumerBinding] = []
  for spec in plan.bindings {
    let raw_contract = match
      read_contract_snapshot(manifest, "consumer", spec.contract) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let contract = match
      @configscope.ConfigConsumerContract::from_value(raw_contract) {
      Ok(v) => v
      Err(_) =>
        return Err("invalid consumer contract in release manifest binding")
    }
    let baseline = match
      read_contract_snapshot(manifest, "baseline", spec.baseline) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    match
      @configscope.ConfigConsumerBinding::new(
        spec.consumer,
        spec.version,
        spec.baseline_id,
        contract,
        baseline,
      ) {
      Ok(binding) => bindings.push(binding)
      Err(error) => return Err(error)
    }
  }
  let report = match
    @configscope.ConfigConsumerReleaseReport::check(bindings, candidate) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let output = render_consumer_release(
    manifest,
    plan.candidate,
    report,
    plan.bindings,
    plan.policy,
  )
  if consumer_release_allowed(report, plan.policy) {
    Ok(output)
  } else {
    Err(output)
  }
}
