import unittest
import wasm3
import wasm3/wasm3c

suite "Raw C wrapping":
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
    check addFunc.isType([I32, I32], [I32])
    check multiplyFunc.isType([I32, I32], [I32])

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
      var sp = sp.stackPtrToUint
      proc doStuff(a, b: int32): int32 = a * b
      callHost(doStuff, sp, mem)

    proc arrPassTest(runtime: PRuntime; ctx: PImportContext; sp: ptr uint64; mem: pointer): pointer {.cdecl.} =
      var sp = sp.stackPtrToUint()
      proc arrPass(a: array[4, int32]) = check a == [10i32, 20, 30, 40]
      callHost(arrPass, sp, mem)


    check m3_ParseModule(env, module.addr, cast[ptr uint8](mathsData[0].addr), uint32 mathsData.len).isNil
    check m3_LoadModule(runtime, module).isNil
    check m3LinkWasi(module).isNil
    check m3_LinkRawFunction(module, "*", "doThing", "i(ii)", doThing).isNil
    check m3_LinkRawFunction(module, "*", "arrPass", "v(i)", arrPassTest).isNil
    check m3_CompileModule(module).isNil


    var indirect: PFunction
    check m3_FindFunction(indirect.addr, runtime, "indirectCall").isNil
    check indirect != nil
    check indirect.isType([I32, I32], [])
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
    check getMyType.isType([], [])
    getMyType.call(void)

    var sizeOfMem = 0u32
    let data = m3_GetMemory(runtime, addr sizeofMem, 0)
    var myType: MyType
    copyMem(myType.addr, cast[pointer](cast[uint64](data) + cast[uint64](globalVal.i32)), sizeof(myType))
    check myType == MyType(x: 100, y: 300, z: 300, w: 15)
    copyMem(myType.addr, cast[pointer](cast[uint64](data) + cast[uint64](globalVal.i32) + uint64 sizeof(MyType)), sizeof(myType))
    check myType == MyType()

suite "Idiomtic Nim Wrapping":
  test "Basic load module and call procedure":
    let
      env = loadWasmEnv(readFile"maths.wasm")
      addFunc = env.findFunction("add")
      multiplyFunc = env.findFunction("multiply")
    check addFunc.call(int32, 3i32, 4i32) == 7i32
    check multiplyFunc.call(int32, 3i32, 4i32) == 12i32
  test "Setup a hook function and call it indirectly":

    type MyType = object
      x, y, z: int32
      w: float32


    proc doThing(runtime: PRuntime; ctx: PImportContext; sp: ptr uint64; mem: pointer): pointer {.cdecl.} =
      var sp = sp.stackPtrToUint()
      proc doStuff(a, b: int32): int32 = a * b
      callHost(doStuff, sp, mem)

    proc arrPassTest(a: array[4, int32]) = check a == [10i32, 20, 30, 40]

    let
      env = loadWasmEnv(readFile"hooks.wasm", hostProcs = [
        wasmHostProc("*", "doThing", "i(ii)", doThing),
        arrPassTest.toWasmHostProc("*", "arrPass", "v(i)")
        ]
      )
      indirect = env.findFunction("indirectCall", [I32, I32], [])
      arrPass = env.findFunction("callArrPass", [], [])

    indirect.call(void, 10i32, 20i32)
    arrPass.call(void)

    let global = env.getGlobal("myArray")
    check global.kind == I32

    env.findFunction("getMyType", [], []).call(void)

    check env.getFromMem(MyType, cast[uint32](global.i32)) == MyType(x: 100, y: 300, z: 300, w: 15)
    check env.getFromMem(MyType, cast[uint32](global.i32), uint64 sizeof(MyType)) == MyType()

  test "Setup a hook function and call it indirectly using wasmconversions":

    type MyType = object
      x, y, z: int32
      w: float32


    proc doThing(runtime: PRuntime; ctx: PImportContext; sp: ptr uint64; mem: pointer): pointer {.cdecl.} =
      var sp = sp.stackPtrToUint()
      extractAs(res, ptr int32, sp, mem)
      extractAs(a, int32, sp, mem)
      extractAs(b, int32, sp, mem)
      res[] = a * b

    proc arrPassTest(runtime: PRuntime; ctx: PImportContext; sp: ptr uint64; mem: pointer): pointer {.cdecl.} =
      var sp = sp.stackPtrToUint()
      extractAs(val, array[4, int32], sp, mem)
      check val == [10i32, 20, 30, 40]

    let
      env = loadWasmEnv(readFile"hooks.wasm", hostProcs = [
        wasmHostProc("*", "doThing", "i(ii)", doThing),
        wasmHostProc("*", "arrPass", "v(i)", arrPassTest)
        ]
      )

      indirect = env.findFunction("indirectCall", [I32, I32], [])

    indirect.call(void, 10i32, 20i32)

    let global = env.getGlobal("myArray")
    check global.kind == I32

    env.findFunction("getMyType", [], []).call(void)

    check env.getFromMem(MyType, cast[uint32](global.i32)) == MyType(x: 100, y: 300, z: 300, w: 15)
    check env.getFromMem(MyType, cast[uint32](global.i32), uint64 sizeof(MyType)) == MyType()


  test "Setup log hook function and call it":

    proc logProc(runtime: PRuntime; ctx: PImportContext; sp: ptr uint64; mem: pointer): pointer {.cdecl.} =
      var sp = sp.stackPtrToUint()
      extractAs(msg, cstring, sp, mem)
      echo msg

    let env = loadWasmEnv(readFile"log.wasm", hostProcs = [wasmHostProc("*", "logIt", "v(i)", logProc)])

    env.findFunction("main", [], []).call(void)


  test "Setup log hook function and call it, using callHost":


    proc logProc(runtime: PRuntime; ctx: PImportContext; sp: ptr uint64; mem: pointer): pointer {.cdecl.} =
      proc logProcImpl(c: cstring) =
        echo c
      var sp = sp.stackPtrToUint()
      callHost(logProcImpl, sp, mem)

    let env = loadWasmEnv(readFile"log.wasm", hostProcs = [wasmHostProc("*", "logIt", "v(i)", logProc)])

    env.findFunction("main", [], []).call(void)







