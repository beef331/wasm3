import wasm3/exporter
proc logIt(s: cstring){.importc.}

proc main*() {.wasmexport.} =
  logIt"Hello"
  logIt"World"
  var a = "This is a test"
  logIt cstring(a)
