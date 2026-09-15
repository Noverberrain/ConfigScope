$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot
$demoDirectory = Join-Path $repoRoot "_build\demo"
$demoContract = Join-Path $demoDirectory "configscope-demo.contract.json"
$breakingContract = Join-Path $repoRoot "cmd\main\testdata\configscope-breaking.contract.json"

function Invoke-Moon {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  & moon run cmd/main -- @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "MoonBit command failed with exit code $LASTEXITCODE"
  }
}

function Invoke-MoonExpectedFailure {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments,
    [Parameter(Mandatory = $true)]
    [int]$ExpectedExitCode
  )

  $output = & moon run cmd/main -- @Arguments 2>&1
  $exitCode = $LASTEXITCODE
  $outputText = $output | Out-String
  Write-Host $outputText.TrimEnd()
  if ($exitCode -ne $ExpectedExitCode) {
    throw "Expected exit code $ExpectedExitCode, got $exitCode"
  }
  return $outputText
}

$previousLocation = Get-Location
try {
  Set-Location -LiteralPath $repoRoot
  if (Test-Path -LiteralPath $demoDirectory) {
    Remove-Item -LiteralPath $demoDirectory -Recurse -Force
  }
  New-Item -ItemType Directory -Path $demoDirectory -Force | Out-Null

  Write-Host "=== 1. Generate a compatibility contract ==="
  Invoke-Moon -Arguments @(
    "contract-init",
    "cmd/main/testdata/compatibility-compatible.json",
    "cmd/main/testdata/basic.json",
    "--output",
    $demoContract
  )

  Write-Host "`n=== 2. Check a compatible release ==="
  Invoke-Moon -Arguments @("contract-check", $demoContract)

  Write-Host "`n=== 3. Emit a machine-readable JSON report ==="
  Invoke-Moon -Arguments @("contract-check", $demoContract, "--format", "json")

  Write-Host "`n=== 4. Reject a breaking release ==="
  $breakingOutput = Invoke-MoonExpectedFailure `
    -Arguments @("contract-check", $breakingContract) `
    -ExpectedExitCode 1
  if ($breakingOutput -notmatch "result: failed" -or
      $breakingOutput -notmatch "type_changed") {
    throw "Breaking example did not produce the expected failure report"
  }

  Write-Host "`nDemo completed successfully."
  Write-Host "Generated contract: $demoContract"
} finally {
  Set-Location -LiteralPath $previousLocation
}
