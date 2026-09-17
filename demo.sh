#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
demo_dir="$repo_root/_build/demo"
demo_contract="$demo_dir/configscope-demo.contract.json"
breaking_contract="$repo_root/cmd/main/testdata/configscope-breaking.contract.json"

cd "$repo_root"
mkdir -p "$demo_dir"
# contract-init deliberately refuses to overwrite an existing manifest.
rm -f -- "$demo_contract"

printf '%s\n' '=== 1. Generate a compatibility contract ==='
moon run cmd/main -- contract-init \
  cmd/main/testdata/compatibility-compatible.json \
  cmd/main/testdata/basic.json \
  --output "$demo_contract"

printf '\n%s\n' '=== 2. Check a compatible release ==='
moon run cmd/main -- contract-check "$demo_contract"

printf '\n%s\n' '=== 3. Emit a machine-readable JSON report ==='
moon run cmd/main -- contract-check "$demo_contract" --format json

printf '\n%s\n' '=== 4. Reject a breaking release ==='
if breaking_output="$(moon run cmd/main -- contract-check "$breaking_contract" 2>&1)"; then
  breaking_exit=0
else
  breaking_exit=$?
fi
printf '%s\n' "$breaking_output"
if [[ "$breaking_exit" -ne 1 ]]; then
  printf 'Expected exit code 1, got %s\n' "$breaking_exit" >&2
  exit 1
fi
if [[ "$breaking_output" != *'result: failed'* ||
      "$breaking_output" != *'type_changed'* ]]; then
  printf '%s\n' 'Breaking example did not produce the expected failure report' >&2
  exit 1
fi

printf '\n%s\n' 'Demo completed successfully.'
printf 'Generated contract: %s\n' "$demo_contract"
