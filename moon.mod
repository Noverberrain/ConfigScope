// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html

name = "Noverberrain/configscope"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/Noverberrain/ConfigScope.git"

license = "Apache-2.0"

keywords = [ "configuration", "provenance", "validation", "developer-tools" ]

preferred_target = "wasm-gc"

description = "Explainable layered configuration merging and auditing for MoonBit"

import {
  "moonbitlang/x@0.5.1",
}
