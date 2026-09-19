///|
/// A versioned compatibility check described by a JSON manifest.
///
/// The manifest contains one candidate snapshot, at least one historical
/// baseline snapshot, and an optional release gate. Paths are kept as supplied
/// so callers can resolve them relative to the manifest file.
pub struct ConfigCompatibilityContract {
  candidate_path : String
  baseline_paths : Array[String]
  policy : ConfigCompatibilityPolicy
  ignored_paths : Array[ConfigPath]
} derive(Eq, Debug)

///|
/// Parse a compatibility contract from a JSON-compatible value.
///
/// The accepted shape contains string field `candidate`, a non-empty string
/// array field `baselines`, and optional `fail_on` and `ignore_paths` fields.
/// `fail_on` defaults to `breaking`. Unknown object fields are ignored so
/// the manifest can grow without breaking older clients.
pub fn ConfigCompatibilityContract::from_value(
  value : ConfigValue,
) -> Result[ConfigCompatibilityContract, String] {
  if value.kind() != Object {
    return Err("contract must be a JSON object")
  }
  let candidate_path = match value.field("candidate") {
    Some(candidate_value) =>
      match candidate_value.as_string() {
        Some(path) =>
          if path == "" {
            return Err("contract field 'candidate' must be a non-empty string")
          } else {
            path
          }
        None =>
          return Err("contract field 'candidate' must be a non-empty string")
      }
    None => return Err("contract is missing required field 'candidate'")
  }
  let baselines_value = match value.field("baselines") {
    Some(baselines_value) => baselines_value
    None => return Err("contract is missing required field 'baselines'")
  }
  if baselines_value.kind() != Array {
    return Err("contract field 'baselines' must be a non-empty array")
  }
  let baseline_count = baselines_value.length().unwrap()
  if baseline_count == 0 {
    return Err("contract field 'baselines' must be a non-empty array")
  }
  let baseline_paths : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  for index in 0..<baseline_count {
    let baseline_value = match baselines_value.element(index) {
      Some(baseline_value) => baseline_value
      None =>
        return Err(
          "contract field 'baselines' contains an invalid item at index " +
          index.to_string(),
        )
    }
    let path = match baseline_value.as_string() {
      Some(path) =>
        if path == "" {
          return Err(
            "contract baseline at index " +
            index.to_string() +
            " must be a non-empty string",
          )
        } else {
          path
        }
      None =>
        return Err(
          "contract baseline at index " +
          index.to_string() +
          " must be a non-empty string",
        )
    }
    if seen.contains(path) {
      return Err(
        "contract field 'baselines' contains duplicate path '" + path + "'",
      )
    }
    seen[path] = true
    baseline_paths.push(path)
  }
  let policy = match value.field("fail_on") {
    None => BreakingOnly
    Some(policy_value) =>
      match policy_value.as_string() {
        Some("breaking") => BreakingOnly
        Some("behavioral") => NoBehavioralChanges
        Some("any") => NoChanges
        _ =>
          return Err(
            "contract field 'fail_on' must be one of breaking, behavioral, or any",
          )
      }
  }
  let ignored_paths : Array[ConfigPath] = []
  match value.field("ignore_paths") {
    None => ()
    Some(paths_value) => {
      if paths_value.kind() != Array {
        return Err("contract field 'ignore_paths' must be an array")
      }
      let ignored_count = paths_value.length().unwrap()
      let seen_ignored : Map[String, Bool] = Map([])
      for index in 0..<ignored_count {
        let source = match paths_value.element(index) {
          Some(path_value) =>
            match path_value.as_string() {
              Some(source) => source
              None =>
                return Err(
                  "contract ignored path at index " +
                  index.to_string() +
                  " must be a non-empty string",
                )
            }
          None =>
            return Err(
              "contract ignored path at index " +
              index.to_string() +
              " must be a non-empty string",
            )
        }
        if source == "" {
          return Err(
            "contract ignored path at index " +
            index.to_string() +
            " must be a non-empty string",
          )
        }
        let path = match parse_path(source) {
          Ok(path) => path
          Err(error) =>
            return Err(
              "contract ignored path '" +
              source +
              "' is invalid: " +
              error.to_string(),
            )
        }
        let canonical = path.to_string()
        if seen_ignored.contains(canonical) {
          return Err(
            "contract field 'ignore_paths' contains duplicate path '" +
            canonical +
            "'",
          )
        }
        seen_ignored[canonical] = true
        ignored_paths.push(path)
      }
    }
  }
  { candidate_path, baseline_paths, policy, ignored_paths } |> Ok
}

///|
/// Return the candidate snapshot path from the manifest.
pub fn ConfigCompatibilityContract::candidate_path(
  self : ConfigCompatibilityContract,
) -> String {
  self.candidate_path
}

///|
/// Return baseline snapshot paths in manifest order.
pub fn ConfigCompatibilityContract::baseline_paths(
  self : ConfigCompatibilityContract,
) -> Array[String] {
  self.baseline_paths.copy()
}

///|
/// Return the release gate selected by the manifest.
pub fn ConfigCompatibilityContract::policy(
  self : ConfigCompatibilityContract,
) -> ConfigCompatibilityPolicy {
  self.policy
}

///|
/// Return exact configuration paths excluded by this contract.
pub fn ConfigCompatibilityContract::ignored_paths(
  self : ConfigCompatibilityContract,
) -> Array[ConfigPath] {
  self.ignored_paths.copy()
}
