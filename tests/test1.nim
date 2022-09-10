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

var
  argData = [3i32, 4i32]
  argPtrs = [argData[0].addr, argData[1].addr]
  result = new int32


echo addFunc.m3Call(uint32 argPtrs.len, cast[ptr pointer](argPtrs.addr))
echo addFunc.m3_GetResults(1, cast[ptr pointer](result.addr))
check result[] == 7



echo multiplyFunc.m3Call(uint32 argPtrs.len, cast[ptr pointer](argPtrs.addr))
echo multiplyFunc.m3_GetResults(1, cast[ptr pointer](result.addr))
check result[] == 12

