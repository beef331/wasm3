## This module implements generic conversions for most of Nim's primitives.
## These are used for the `callHost` macro.
## One can easily add their own variant for specific types, as it is generally ambiguous how to best handle other types.


type
  WasmTypes* = int32 or uint32 or int64 or uint64 or float32 or float64
  WasmCallable* = concept wt, type WT
    var
      stackPointer: uint64
      mem: pointer
    fromWasm(wt, stackPointer, mem) is void


proc fromWasm*[T: SomeNumber or enum or bool](result: var T, stackPtr: var uint64, mem: pointer) =
  result = cast[ptr T](stackPtr)[]
  stackPtr += uint64 sizeof(pointer)

proc fromWasm*[T](result: var openArray[T], stackPtr: var uint64, mem: pointer) =
  for val in result.mitems:
    val.fromWasm(stackPtr, mem)

proc fromWasm*(result: (var seq) or (var string), stackPtr: var uint64, mem: pointer) =
  var size = 0u32
  size.fromWasm(stackPtr, mem)
  result.setLen(int size)
  for val in result.mitems:
    val.fromWasm(stackPtr, mem)

proc fromWasm*(result: var ptr, stackPtr: var uint64, mem: pointer) =
  result = cast[typeof(result)](stackPtr)
  stackPtr += uint64 sizeof(pointer)

proc stackPtrToUint*(stackPtr: ptr uint64): uint64 = cast[uint64](stackPtr)

template extractAs*(name: untyped, typ: typedesc, stackPtr: var uint64, mem: pointer) =
  let name = block:
    var tmp: typ
    tmp.fromWasm(stackPtr, mem)
    tmp
