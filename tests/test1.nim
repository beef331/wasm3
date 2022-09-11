import unittest
import wasm3


test "Basic load module and call procedure":
  var
    mathsData = readFile("maths.wasm")
    env = m3_NewEnvironment()
    runtime = env.m3_NewRuntime(uint16.high.uint32, nil)
    module: PModule
  check m3_ParseModule(env, module.addr, cast[ptr uint8](mathsData[0].addr), uint32 mathsData.len).isNil
  check m3_LoadModule(runtime, module).isNil
  check m3LinkWasi(module).isNil # We depend on WASI here
  check m3_CompileModule(module).isNil


  var
    addFunc: PFunction
    multiplyFunc: PFunction
  check m3_FindFunction(addFunc.addr, runtime, "add").isNil
  check m3_FindFunction(multiplyFunc.addr, runtime, "multiply").isNil

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
    proc doThing(a, b: int32): int32 = a * b
    callWasm((proc(a, b: int32): int32)(doThing), sp, mem)


  check m3_ParseModule(env, module.addr, cast[ptr uint8](mathsData[0].addr), uint32 mathsData.len).isNil
  check m3_LoadModule(runtime, module).isNil
  check m3LinkWasi(module).isNil
  check m3_LinkRawFunction(module, "*", "doThing", "i(ii)", doThing).isNil
  check m3_CompileModule(module).isNil


  var indirect: PFunction
  check m3_FindFunction(indirect.addr, runtime, "indirectCall").isNil
  check indirect != nil
  indirect.call(void, 10i32, 20i32)

  var global = m3_FindGlobal(module, "myArray")
  check global != nil
  var globalVal: WasmVal
  check global.m3_GetGlobal(addr globalVal).isNil

  type MyType = object
    x, y, z: int32
    w: float32

  var getMyType: PFunction
  check m3_FindFunction(getMyType.addr, runtime, "getMyType").isNil
  check getMyType != nil
  getMyType.call(void)

  var sizeOfMem = uint32 sizeof(MyType)
  let data = m3_GetMemory(runtime, addr sizeofMem, 0)
  var myType: MyType
  copyMem(myType.addr, cast[pointer](cast[uint64](data) + cast[uint64](globalVal.i32)), sizeof(myType))
  check myType == MyType(x: 100, y: 300, z: 300, w: 15)
  copyMem(myType.addr, cast[pointer](cast[uint64](data) + cast[uint64](globalVal.i32) + uint64 sizeof(MyType)), sizeof(myType))
  check myType == MyType()





