///|
fn json_string(value : String) -> Json {
  Json::string(value)
}

///|
fn json_int(value : Int) -> Json {
  Json::number(value.to_double())
}

///|
fn json_change(change : @configscope.ConfigCompatibilityChange) -> Json {
  Json::object(
    Map([
      ("path", json_string(change.path().to_string())),
      ("kind", json_string(change.difference_kind().to_string())),
      ("impact", json_string(change.impact().to_string())),
    ]),
  )
}

///|
fn json_report_summary(
  report : @configscope.ConfigCompatibilityReport,
  policy : @configscope.ConfigCompatibilityPolicy,
) -> Json {
  Json::object(
    Map([
      ("compatible", json_int(report.compatible_count())),
      ("behavioral", json_int(report.behavioral_count())),
      ("breaking", json_int(report.breaking_count())),
      ("changes", json_int(report.change_count())),
      ("violations", json_int(report.violation_count(policy))),
    ]),
  )
}

///|
fn json_report_changes(report : @configscope.ConfigCompatibilityReport) -> Json {
  Json::array(report.changes().map(json_change))
}

///|
fn render_json_compatibility(
  report : @configscope.ConfigCompatibilityReport,
  policy : @configscope.ConfigCompatibilityPolicy,
) -> String {
  Json::object(
    Map([
      ("kind", json_string("compatibility_report")),
      ("gate", json_string(policy.to_string())),
      ("passed", Json::boolean(report.passes(policy))),
      ("summary", json_report_summary(report, policy)),
      ("changes", json_report_changes(report)),
    ]),
  ).stringify()
}

///|
fn json_matrix_entry(
  entry : @configscope.ConfigCompatibilityMatrixEntry,
  policy : @configscope.ConfigCompatibilityPolicy,
) -> Json {
  let report = entry.report()
  Json::object(
    Map([
      ("baseline", json_string(entry.baseline_name())),
      ("passed", Json::boolean(entry.passes(policy))),
      ("summary", json_report_summary(report, policy)),
      ("changes", json_report_changes(report)),
    ]),
  )
}

///|
fn json_matrix_entries(
  report : @configscope.ConfigCompatibilityMatrixReport,
  policy : @configscope.ConfigCompatibilityPolicy,
) -> Json {
  Json::array(report.entries().map(entry => json_matrix_entry(entry, policy)))
}

///|
fn render_json_compatibility_matrix(
  report : @configscope.ConfigCompatibilityMatrixReport,
  policy : @configscope.ConfigCompatibilityPolicy,
) -> String {
  Json::object(
    Map([
      ("kind", json_string("compatibility_matrix")),
      ("gate", json_string(policy.to_string())),
      ("passed", Json::boolean(report.passes(policy))),
      (
        "summary",
        Json::object(
          Map([
            ("passed", json_int(report.passed_count(policy))),
            ("failed", json_int(report.failed_count(policy))),
            ("total", json_int(report.baseline_count())),
          ]),
        ),
      ),
      ("baselines", json_matrix_entries(report, policy)),
    ]),
  ).stringify()
}

///|
fn render_json_compatibility_contract(
  manifest_path : String,
  candidate_path : String,
  report : @configscope.ConfigCompatibilityMatrixReport,
  policy : @configscope.ConfigCompatibilityPolicy,
) -> String {
  Json::object(
    Map([
      ("kind", json_string("compatibility_contract")),
      ("contract", json_string(manifest_path)),
      ("candidate", json_string(candidate_path)),
      ("gate", json_string(policy.to_string())),
      ("passed", Json::boolean(report.passes(policy))),
      (
        "summary",
        Json::object(
          Map([
            ("passed", json_int(report.passed_count(policy))),
            ("failed", json_int(report.failed_count(policy))),
            ("total", json_int(report.baseline_count())),
          ]),
        ),
      ),
      ("baselines", json_matrix_entries(report, policy)),
    ]),
  ).stringify()
}
