import wasm3/wasm3c
# This stuff here is likely to get moved to another module eventually
import std/[macros, genasts, typetraits, enumerate, tables]
import micros



type
  WasmError* = object of CatchableError
  WasmTypes* = int32 or uint32 or int64 or uint64 or float32 or float64

proc wasmValidTuple*(t: typedesc[tuple]): bool =
  result = true
  for field in fields t():
    when field isnot WasmTypes:
      return false

type
  WasmTuple* = concept wasmt, type WT
    WT is tuple
    wasmValidTuple(WT)
  WasmType = concept wt, type WT # TODO: implement an interface to allow user defined types to be transferred to wasm with generic hooks
    var
      alloc: PFunction
      free: PFunction
      stackPointer: ptr uint64
    wt.toWasm(alloc, free)
    fromWasm[WT](stackPointer) is WT

  WasmEnv* = ref object # ref counting is good for the soul
    env: PEnv
    runtime: PRuntime
    module: PModule
    wasmData: string # have to keep data alive

  AllowedWasmType* = WasmTypes or void or WasmTuple


proc `=destroy`(we: var typeof(WasmEnv()[])) =
  m3FreeModule(we.module)
  m3FreeRuntime(we.runtime)

proc loadWasmEnv*(wasmData: sink string, stackSize: uint32 = high(uint16)): WasmEnv =
  new result
  result.wasmData = wasmData
  result.env = m3_NewEnvironment()
  result.runtime = result.env.m3_NewRuntime(stackSize, nil)

  var wasmRes = m3_ParseModule(result.env, result.module.addr, cast[ptr uint8](result.wasmData[0].addr), uint32 result.wasmData.len)
  template resCheck =
    if wasmRes != nil:
      raise newException(WasmError, $wasmRes)

  resCheck()
  wasmRes = m3_LoadModule(result.runtime, result.module)
  resCheck()
  when defined wasm3HasWasi: # Maybe an if statement?
    wasmRes = m3LinkWasi(result.module)
    resCheck()
  wasmRes = m3_CompileModule(result.module)
  resCheck()

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
    let resultsResult = m3_GetResults(theFunc, uint32 ptrArray.len, cast[ptr pointer](ptrArray.addr))
    if resultsResult != nil:
      raise newException(WasmError, $resultsResult)
    res

macro call*(theFunc: PFunction, returnType: typedesc[WasmTuple or WasmTypes or void],  args: varargs[typed]): untyped =
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
        let callResult = callProc(theFunc, uint32 len arrVal, cast[ptr pointer](arrVal.addr))
        if callResult != nil:
          raise newException(WasmError, $callResult)
        getResult[returnType](theFunc)
  else:
    result.add:
        genast(returnType, theFunc, callProc = bindsym"m3_Call"):
          let callResult = callProc(theFunc, 0, nil)
          if callResult != nil:
            raise newException(WasmError, $callResult)
          getResult[returnType](theFunc)

macro callWasm*(p: proc, stackPointer: ptr uint64, mem: pointer): untyped =
  ## This takes a proc, stackPointer and mem, and creates something along the lines of
  ## `cast[ptr returnType(p)](stackPointer) = p(cast[ptr typeof(param[0])](stackPointer + sizeof(uint64) * 0)[], ..)`
  let
    pSym = routineSym(p)
    pDef = block:
      var res: RoutineNode
      for sym in psym.routines:
        if NimNode(res).isNil:
          res = sym
        else:
          error("Cannot 'callWasm' on an overloaded symbol use some method to specify it", p)
      res
    retT = pDef.returnType
  let hasReturnType = not retT.sameType(getType(void))
  var offset =
    if hasReturnType:
      1
    else:
      0

  result = newStmtList()
  var call = macros.newCall(p)
  type ValidParamType = WasmTypes or WasmTuple
  for args in pDef.params:
    let typ = args.typ
    for _ in args.names:
      call.add:
        genast(stackPointer, typ, offset = newLit(offset), ValidParamType):
          when typ isnot ValidParamType:
            {.error: "Cannot convert to paramter type of '" & $typ & "'.".}
          cast[ptr typ](cast[uint64](stackPointer) + sizeof(uint64) * offset)[]
      inc offset
  result =
    if hasReturnType:
      genast(retT, call, stackPointer, AllowedWasmType):
        when retT isnot AllowedWasmType:
          {.error: "Cannot convert to given return type '" & $retT & "'.".}
        cast[ptr retT](stackPointer)[] = call
    else:
      call


proc isType*(fnc: PFunction, args, results: openArray[ValueKind]): bool =
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
  let wasmRes = m3FindFunction(result.addr, wasmEnv.runtime, name)
  if wasmRes != nil:
    raise newException(WasmError, $wasmRes)


proc findFunction*(wasmEnv: WasmEnv, name: string, args, results: openarray[ValueKind]): PFunction =
  result = wasmEnv.findFunction(name)
  if not result.isType(args, results):
    {.warning: "Insert rendered proc here".}
    raise newException(WasmError, "Function is not the type requested.")

