import unittest
import wasm3
import wasm3/wasm3c


type
  MyType = object
    x: int32
    y: bool
    z: string


proc wasmSize(_: typedesc[MyType]): uint32 = uint32(sizeof(int32) + sizeof(bool) + sizeof(uint32))
proc wasmSize(_: typedesc[string]): uint32 = uint32 sizeof(uint32)

proc wasmCopy(myString: string, env: WasmEnv, dest: WasmPtr, offset: var uint64) =
  let dataPtr = env.alloc(uint32 myString.len + 1) # '\0' included
  env.copyMem(dataPtr, myString[0].unsafeaddr, myString.len + 1)
  env.copyMem(dest.uint32, dataPtr.unsafeaddr, sizeof(WasmPtr), uint32 offset)
  offset.offsetBy(string)

proc wasmCopy(myType: MyType, env: WasmEnv, dest: WasmPtr, offset: var uint64) =
  for field in myType.fields:
    field.wasmCopy(env, dest, offset) # Copy offsets `offset`


proc wasmSize(_: typedesc[array]): uint32 = uint32 sizeof(uint32)

proc wasmAlloc[T](oa: openArray[T], env: WasmEnv, wPtr: WasmPtr) =
  const elemSize = uint32 getWasmSize(typeof(oa[0]))

  var dataPtr = env.alloc(elemSize * uint32 oa.len)
  env.setMem(uint32(oa.len), wPtr)
  env.setMem(dataPtr, wPtr, offset = uint64 sizeof(int32))
  var offset = 0u64
  for element in oa:
    element.wasmCopy(env, dataPtr, offset)

proc wasmDealloc(wPtr: WasmPtr, env: WasmEnv, _: typedesc[openarray[MyType]]) = discard
proc wasmDealloc(wPtr: WasmPtr, env: WasmEnv, _: typedesc[string]) = discard

suite "Host to Wasm interop":
  test "Ensure basic interfaces work":
    let
      env = loadWasmEnv(readFile"hostinterop.wasm", loadAlloc = true)
      arrCheck1 = env.findFunction("arrCheck1", [I32], [I32])
      arrCheck2 = env.findFunction("arrCheck2", [I32], [I32])
      getCstringArray = env.findFunction("returnCstringArray", [I32], [I32])
      getSizedCstringArray = env.findFunction("returnSizedCstringArray", [I32], [I32])

    const myArr1 = [10i32, 20, 30, 40]
    let arr1Alloc = env.alloc(myArr1)
    check arrCheck1.call(bool, arr1Alloc)


    const myArr2 = [
      MyType(x: 100, y: true, z: "hello world"),
      MyType(x: 42, y: false, z: "Bleh"),
      MyType(x: 314159265i32, y: false, z: "Meh"),
    ]

    let arr2Alloc = env.alloc(myArr2)

    check arrCheck2.call(bool, arr2Alloc)

    test "cstring interop":
      var
        len = env.alloc(0)
        theAddr = getCstringArray.call(WasmPtr, len)

      const strs = ["hello", "world", ""]

      for i in 0..<env.getFromMem(int32, uint32(len)):
        let strStart = env.getFromMem(WasmPtr, uint32 theAddr, uint64 i * sizeof(uint32))
        var
          offset = 0u64
          str = ""
        while (let val = env.getFromMem(char, uint32 strStart, offset); val != '\0'):
          str.add val.char
          inc offset
        check strs[i] == str

      theAddr = getSizedCstringArray.call(WasmPtr, len)

      for i in 0..<env.getFromMem(int32, uint32(len)):
        let
          strPtr = env.getFromMem(int32, uint32 theAddr, uint64 i * (sizeof(uint32) * 2))
          strLen = env.getFromMem(int32, uint32 theAddr, uint64 i * (sizeof(uint32) * 2) + sizeof(uint32))
        let str = newString(int strLen)
        if strLen > 0:
          env.copyFromMem(uint32 strPtr, str[0].addr, int strLen)

        check str == strs[i]



