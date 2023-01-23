## This module implements generic conversions for most of Nim's primitives.
## These are used for the `callHost` macro.
## One can easily add their own variant for specific types, as it is generally ambiguous how to best handle other types.
import wasm3
import std/[enumerate, typetraits]

type
  WasmBultinType = int32 or uint32 or int64 or uint64 or float32 or float64 or WasmPtr or bool

  WasmBase* = concept type W
    distinctBase(W) is WasmBultinType

  WasmTypes* = WasmBase or WasmBultinType

  WasmPtr* = distinct uint32 # Opaque type to make it less 'low level'

  WasmStackDeserialisable* = concept data
    var
      stackPointer: uint64
      mem: pointer
    fromWasm(data, stackPointer, mem) # We are extracting on the stack so we only need `stackPointer` and `mem` for any children data

  WasmHeapDeserialisable* = concept data, type Data
    var
      mem: pointer
      i: int
    fromWasm(data, mem, i) # We arent extracting on the stack, so we only need `mem` and `offset`
    wasmSize(Data) is uint32 # For offsetting on heap.

  WasmAllocatable* = concept wa, type Wa
    var
      env: WasmEnv
      wPtr: WasmPtr
    wasmSize(Wa) is uint32
    wasmAlloc(wa, env, wPtr)
    #wasmDealloc[Wa](wPtr, env) # Maybe we should force this?

  WasmCopyable* = concept wc
    var
      env: WasmEnv
      wasmPtr: WasmPtr
      offset: uint64
    wasmCopy(wc, env, wasmPtr, offset)

  SomeNumeric = SomeNumber or enum or bool and not(int or uint) # Do not allow platform specific integers to prevent 32 vs. 64bit issues

proc wasmSize*[T: SomeNumeric](_: typedesc[T]): uint32 = uint32 sizeof(T)

proc fromWasm*[T: SomeNumeric](result: var T, memStart: pointer, offset: int) =
  # Numeric heap deserialisation
  copyMem(result.addr, cast[pointer](cast[uint64](memStart) + uint64(offset)), sizeof(result))

proc fromWasm*[T: SomeNumeric](result: var T, stackPtr: var uint64, mem: pointer) =
  # Numeric stack deserialisation
  result = cast[ptr T](stackPtr)[]
  stackPtr += uint64 sizeof(pointer)

proc fromWasm*[T: WasmHeapDeserialisable](result: var openArray[T], stackPtr: var uint64, mem: pointer) =
  mixin wasmSize, fromWasm
  var ind: uint32
  ind.fromWasm(stackPtr, mem)
  for i, val in enumerate result.mitems:
    val.fromWasm(mem, i * wasmSize(T).int + int ind)

proc fromWasm*(result: var ptr, stackPtr: var uint64, mem: pointer) =
  # Mainly for return values
  result = cast[typeof(result)](stackPtr)
  stackPtr += uint64 sizeof(pointer)

proc fromWasm*(cstr: var cstring, sp: var uint64, mem: pointer) =
  var i: uint32
  i.fromWasm(sp, mem)
  cStr = cast[cstring](cast[uint64](mem) + i)

proc stackPtrToUint*(stackPtr: ptr uint64): uint64 = cast[uint64](stackPtr)

template extractAs*(name: untyped, typ: typedesc, stackPtr: var uint64, mem: pointer) =
  let name = block:
    var tmp: typ
    tmp.fromWasm(stackPtr, mem)
    tmp

proc offsetBy*(offset: var uint64, T: typedesc) =
  mixin wasmSize
  offset += uint64 wasmSize(T)

proc wasmCopy*(num: SomeNumeric, wasmEnv: WasmEnv, wasmPtr: WasmPtr, offset: var uint64) =
  wasmEnv.setMem(num, wasmPtr, offset)
  offset.offsetBy(SomeNumeric)

