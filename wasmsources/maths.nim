import wasm3/exporter
proc add(a, b: int32): int32 {.wasmexport.} = a + b
proc multiply(a, b: int32): int32 {.wasmexport.} = a * b
