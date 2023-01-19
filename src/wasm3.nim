import wasm3/[wasm3c, wasmconversions]
# This stuff here is likely to get moved to another module eventually
import std/[macros, genasts, typetraits, enumerate, tables]
import micros

export wasmconversions

type
  WasmError* = object of CatchableError

proc wasmValidTuple*(t: typedesc[tuple]): bool =
  result = true
  for field in fields t():
    when field isnot WasmTypes:
      return false

type
  WasmTuple* = concept wasmt, type WT
    WT is tuple
    wasmValidTuple(WT)


  WasmEnv* = ref object # ref counting is good for the soul
    env: PEnv
    runtime: PRuntime
    module: PModule
    wasmData: string # have to keep data alive
    allocFunc, deallocFunc: PFunction

  WasmHostProc* = object
    module, name, typ: string
    prc: WasmProc

  AllowedWasmType* = WasmTypes or void or WasmTuple

  WasmPtr* = distinct uint32

  WasmAllocatable* = concept wa
    var dest: ptr uint8
    wasmSize(wa) is uint32
    wasmCopyTo(wa, dest)


proc checkWasmRes*(res: Result) {.inline.} =
  if res != nil:
    raise newException(WasmError, $res)

proc `=destroy`(we: var typeof(WasmEnv()[])) =
  m3FreeRuntime(we.runtime)
  m3FreeEnvironment(we.env)
  `=destroy`(we.wasmData)

proc findFunction*(wasmEnv: WasmEnv, name: string, args, results: openarray[ValueKind]): PFunction

proc loadWasmEnv*(
  wasmData: sink string,
  stackSize: uint32 = high(uint16),
  hostProcs: openarray[WasmHostProc] = [],
  loadAlloc = false
  ): WasmEnv =
  new result
  result.wasmData = wasmData
  result.env = m3_NewEnvironment()
  result.runtime = result.env.m3_NewRuntime(stackSize, nil)

  checkWasmRes m3_ParseModule(result.env, result.module.addr, cast[ptr uint8](result.wasmData[0].addr), uint32 result.wasmData.len)
  try:
    checkWasmRes m3_LoadModule(result.runtime, result.module)
  except WasmError:
    m3FreeModule(result.module)
    raise

  when defined wasm3HasWasi: # Maybe an if statement?
    checkWasmRes m3LinkWasi(result.module)
  for hostProc in hostProcs:
    checkWasmRes m3LinkRawFunction(result.module, cstring hostProc.module, cstring hostProc.name, cstring hostProc.typ, hostProc.prc)
  checkWasmRes m3_CompileModule(result.module)

  if loadAlloc:
    result.allocFunc = result.findFunction("alloc", [I32], [I32])
    result.deallocFunc = result.findFunction("dealloc", [I32], [])

proc ptrArrayTo*(t: var WasmTypes): array[1, pointer] = [pointer(addr t)]

proc ptrArrayTo*(t: var WasmTuple): auto =
 result = default(array[tupleLen(t), pointer])
 for i, x in enumerate t.fields:
   result[i] = pointer(x.addr)

template getResult*[T: WasmTuple or WasmTypes](theFunc: PFunction): untyped =
  when T is void:
    discard
  else:
    var
      res: T
      ptrArray = res.ptrArrayTo
    checkWasmRes m3_GetResults(theFunc, uint32 ptrArray.len, cast[ptr pointer](ptrArray.addr))
    res

macro call*(theFunc: PFunction, returnType: typedesc[WasmTuple or WasmTypes or void],  args: varargs[typed]): untyped =
  ## Calls
  result = newStmtList()
  let arrVals = nnkBracket.newTree()
  for arg in args:
    let argName = genSym(nskVar)
    result.add:
      genast(argName, arg):
        var argName = arg
    arrVals.add:
      genAst(argName):
        pointer(addr argName)
  if args.len > 0:
    result.add:
      genast(returnType, theFunc, arrVals, callProc = bindsym"m3_Call"):
        var arrVal = arrVals
        checkWasmRes callProc(theFunc, uint32 len arrVal, cast[ptr pointer](arrVal.addr))
        getResult[returnType](theFunc)
  else:
    result.add:
        genast(returnType, theFunc, callProc = bindsym"m3_Call"):
          checkWasmRes callProc(theFunc, 0, nil)
          getResult[returnType](theFunc)

macro callHost*(p: proc, stackPointer: var uint64, mem: pointer): untyped =
  ## This takes a proc, stackPointer and mem.
  ## It emits `fromWasm` for each argument, and `ptr ReturnType` for the return value.
  ## It then calls the proc with args and sets the return value.
  let
    typ = p.getType()
    retT = typ[1]
    hasReturnType = not typ[1].getType.sameType(getType(void))
    call = newCall(p)
  for typ in typ[2..^1]:
    call.add:
      genast(stackPointer, mem, typ = typ.getTypeInst()):
        let arg = block:
          var val = default(typeof(typ))
          val.fromWasm(stackPointer, mem)
          val
        arg
  result =
    if hasReturnType:
      genast(retT, call, stackPointer):
        let retType = block:
          var val: ptr retT
          val.fromWasm(stackPointer, mem)
          val
        retType[] = call
    else:
      call

proc wasmHostProc*(module, name, typ: string, prc: WasmProc): WasmHostProc =
  WasmHostProc(module: module, name: name, typ: typ, prc: prc)

macro toWasmHostProc*(p: proc, module, name, typ: string): untyped =
  genAst(p, modle = module, nam = name, ty = typ):
    WasmHostProc(
      module: modle,
      name: nam,
      typ: ty,
      prc: proc (runtime: PRuntime; ctx: PImportContext; sp: ptr uint64; mem: pointer): pointer {.cdecl.} =
        var sp = sp.stackPtrToUint()
        callHost(p, sp, mem)
      )

proc isType*(fnc: PFunction, args, results: openArray[ValueKind]): bool =
  # Returns whether a wasm module's function matches the type signature supplied.
  result = true
  if m3_GetRetCount(fnc) != uint32(results.len) or m3_GetArgCount(fnc) != uint32(args.len):
    return false
  for i, arg in args:
    if arg != m3_GetArgType(fnc, uint32 i):
      return false
  for i, res in results:
    if res != m3_GetRetType(fnc, uint32 i):
      return false

proc findFunction*(wasmEnv: WasmEnv, name: string): PFunction =
  checkWasmRes m3FindFunction(result.addr, wasmEnv.runtime, cstring name)

proc findFunction*(wasmEnv: WasmEnv, name: string, args, results: openarray[ValueKind]): PFunction =
  result = wasmEnv.findFunction(name)
  if not result.isType(args, results):
    {.warning: "Insert rendered proc here".}
    raise newException(WasmError, "Function is not the type requested.")

proc findGlobal*(wasmEnv: WasmEnv, name: string): PGlobal =
  result = m3FindGlobal(wasmEnv.module, cstring name)
  if result.isNil:
    raise newException(WasmError, "Global named '" & name & "' is not found.")

proc getGlobal*(global: PGlobal): WasmVal =
  checkWasmRes m3GetGlobal(global, result.addr)

proc getGlobal*(wasmEnv: WasmEnv, name: string): WasmVal =
  wasmEnv.findGlobal(name).getGlobal()

proc getFromMem*(wasmEnv: WasmEnv, T: typedesc, pos: uint32, offset: uint64 = 0): T =
  var sizeOfMem: uint32
  let thePtr = m3GetMemory(wasmEnv.runtime, addr sizeOfMem, 0)
  if pos + uint32(sizeof(T)) + uint32(offset) > sizeOfMem:
    raise newException(WasmError, "Attempted to read outside of memory bounds")
  copyMem(result.addr, cast[pointer](cast[uint64](thePtr) + cast[uint64](pos) + offset), sizeof(T))

proc setMem*[T](wasmEnv: WasmEnv, val: T, pos: uint32, offset: uint64 = 0) =
  var sizeOfMem: uint32
  let thePtr = m3GetMemory(wasmEnv.runtime, addr sizeOfMem, 0)
  if pos + uint32(sizeof(T)) + uint32(offset) > sizeOfMem:
    raise newException(WasmError, "Attempted to write outside of memory bounds")
  copyMem(cast[pointer](cast[uint64](thePtr) + cast[uint64](pos) + offset), val.unsafeAddr, sizeof typeof(val))


proc copyMem*(wasmEnv: WasmEnv, pos: uint32, p: pointer, len: int) =
  var sizeOfMem: uint32
  let thePtr = m3GetMemory(wasmEnv.runtime, addr sizeOfMem, 0)
  if pos + uint32(len) > sizeOfMem:
    raise newException(WasmError, "Attempted to write outside of memory bounds")
  copyMem(cast[pointer](cast[uint64](thePtr) + cast[uint64](pos)), p, len)

proc copyTo*[T: WasmAllocatable](wasmEnv: WasmEnv, data: T): WasmPtr =
  mixin wasmCopyTo, wasmSize
  let size = data.wasmSize()
  result = WasmPtr(wasmEnv.allocFunc.call(uint32, size))
  var memSize: uint32
  let dest = wasmEnv.env.m3GetMemory(memSize.addr, uint32 result)
  data.wasmCopyTo(dest)


