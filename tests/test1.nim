import unittest
import wasm3


template wasmVal*(i: int32): auto = WasmVal(kind: I32, i32: i)

var
  mathsData = readFile("maths.wasm")
  env = m3_NewEnvironment()
  runtime = env.m3_NewRuntime(uint16.high.uint32, nil)
  module: PModule
echo m3_ParseModule(env, module.addr, cast[ptr uint8](mathsData[0].addr), uint32 mathsData.len), "A"
echo m3_LoadModule(runtime, module)
echo m3_CompileModule(module)


var
  addFunc: PFunction
  multiplyFunc: PFunction
discard m3_FindFunction(addFunc.addr, runtime, "add")
discard m3_FindFunction(multiplyFunc.addr, runtime, "multiply")

check addFunc.m3GetFunctionName() == "add"
check multiplyFunc.m3GetFunctionName() == "multiply"

check addFunc.call(int32, 3i32, 4i32) == 7i32
check multiplyFunc.call(int32, 3i32, 4i32) == 12
