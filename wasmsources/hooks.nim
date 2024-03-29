import wasm3/exporter

proc doThing(a, b: int32): int32 {.importC.}

proc arrPass(a: array[4, int32]) {.importc.}

proc indirectCall(a, b: int32) {.wasmexport.} =
  assert doThing(a, b) == a * b

proc getFloat(a, b: int32): float32 {.wasmexport.} = discard


type MyType = object
  x, y, z: int32
  w: float32

exportVar(myArray, array[100, MyType])

proc getMyType() {.wasmexport.} =
  myArray[0] = MyType(x: 100, y: 300, z: 300, w: 15)

proc callArrPass() {.wasmexport.} = arrPass([10i32, 20, 30, 40])
