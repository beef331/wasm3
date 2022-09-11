import unittest
import wasm3


test "Basic load module and call procedure":
  var
    mathsData = readFile("maths.wasm")
    env = m3_NewEnvironment()
    runtime = env.m3_NewRuntime(uint16.high.uint32, nil)
    module: PModule
  check m3_ParseModule(env, module.addr, cast[ptr uint8](mathsData[0].addr), uint32 mathsData.len) == nil
  check m3_LoadModule(runtime, module) == nil
  check m3LinkWasi(module) == nil # We depend on WASI here
  check m3_CompileModule(module) == nil


  var
    addFunc: PFunction
    multiplyFunc: PFunction
  check m3_FindFunction(addFunc.addr, runtime, "add") == nil
  check m3_FindFunction(multiplyFunc.addr, runtime, "multiply") == nil

  check addFunc.m3GetFunctionName() == "add"
  check multiplyFunc.m3GetFunctionName() == "multiply"

  check addFunc.call(int32, 3i32, 4i32) == 7i32
  check multiplyFunc.call(int32, 3i32, 4i32) == 12

test "Setup a hook function and call it indirectly":
  var
    mathsData = readFile("hooks.wasm")
    env = m3_NewEnvironment()
    runtime = env.m3_NewRuntime(uint16.high.uint32, nil)
    module: PModule

  proc doThing(runtime: PRuntime; ctx: PImportContext; sp: ptr uint64; mem: pointer): pointer {.cdecl.} =
    var sp = cast[uint64](sp)
    let
      rawReturn = cast[ptr int32](sp)
      a = cast[ptr int32](sp + 8)[]
      b = cast[ptr int32](sp + 16)[]
    rawReturn[] = a * b

  check m3_ParseModule(env, module.addr, cast[ptr uint8](mathsData[0].addr), uint32 mathsData.len) == nil
  check m3_LoadModule(runtime, module) == nil
  check m3LinkWasi(module) == nil
  check m3_LinkRawFunction(module, "*", "doThing", "i(ii)", doThing) == nil
  check m3_CompileModule(module) == nil


  var indirect: PFunction
  check m3_FindFunction(indirect.addr, runtime, "indirectCall") == nil
  check indirect != nil
  indirect.call(void, 10i32, 20i32)
