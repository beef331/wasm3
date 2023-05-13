import std/os

const wasmDir = currentSourcePath().parentDir() / "/wasm3c/source/"
{.passC: "-I" & wasmDir.}

when defined(wasm3HasWasi):
  {.passC: "-D" & "d_m3HasWASI".}
  {.compile: wasmDir / "m3_api_libc.c".}
  {.compile: wasmDir / "m3_api_wasi.c".}
  {.compile: wasmDir / "m3_api_uvwasi.c".}
  {.compile: wasmDir / "m3_api_meta_wasi.c".}

when defined(wasm3VerboseErrorMessages):
  {.passC: "-D" & "DEBUG".}
  {.passC: "-D" & "d_m3VerboseErrorMessages=1".}

when defined(wasm3LogParse):
  {.passC: "-D" & "DEBUG".}
  {.passC: "-D" & "d_m3LogParse=1".}

when defined(wasm3LogModule):
  {.passC: "-D" & "DEBUG".}
  {.passC: "-D" & "d_m3LogModule=1".}

when defined(wasm3LogCompile):
  {.passC: "-D" & "DEBUG".}
  {.passC: "-D" & "d_m3LogCompile=1".}

when defined(wasm3LogWasmStack):
  {.passC: "-D" & "DEBUG".}
  {.passC: "-D" & "d_m3LogWasmStack=1".}

when defined(wasm3LogEmit):
  {.passC: "-D" & "DEBUG".}
  {.passC: "-D" & "d_m3LogEmit=1".}

when defined(wasm3LogCodePages):
  {.passC: "-D" & "DEBUG".}
  {.passC: "-D" & "d_m3LogCodePages=1".}

when defined(wasm3LogRuntime):
  {.passC: "-D" & "DEBUG".}
  {.passC: "-D" & "d_m3LogRuntime=1".}

when defined(wasm3LogNativeStack):
  {.passC: "-D" & "DEBUG".}
  {.passC: "-D" & "d_m3LogNativeStack=1".}

{.compile: wasmDir / "m3_api_tracer.c".}
{.compile: wasmDir / "m3_bind.c".}
{.compile: wasmDir / "m3_code.c".}
{.compile: wasmDir / "m3_compile.c".}
{.compile: wasmDir / "m3_core.c".}
{.compile: wasmDir / "m3_env.c".}
{.compile: wasmDir / "m3_exec.c".}
{.compile: wasmDir / "m3_function.c".}
{.compile: wasmDir / "m3_info.c".}
{.compile: wasmDir / "m3_module.c".}
{.compile: wasmDir / "m3_parse.c".}

type
  ValueKind* = enum
    None = 0, I32 = 1, I64 = 2, F32 = 3,
    F64 = 4, Unknown
  WasmVal* {.bycopy.} = object
    case kind*: ValueKind
    of I32:
      i32*: int32
    of I64:
      i64*: int64
    of F32:
      f32*: float32
    of F64:
      f64*: float64
    else:
      discard


{. push header: "wasm3.h".}
type
  Result* = cstring

  Environment* = object
  Runtime* = object
  Module* = object
  Function* = object

  PEnv* = ptr Environment

  PRuntime* = ptr Runtime

  PModule* = ptr Module

  PFunction* = ptr Function

  Global* = object
  PGlobal* = ptr Global
  ErrorInfo* {.bycopy.} = object
    result*: Result
    runtime*: PRuntime
    module*: PModule
    function*: PFunction
    file*: cstring
    line*: uint32
    message*: cstring

  BackTraceFrame* {.bycopy.} = object
    moduleOffset*: uint32
    function*: PFunction
    next*: ptr BackTraceFrame

  PBackTraceFrame* = ptr BacktraceFrame
  M3BacktraceInfo* {.bycopy.} = object
    frames*: PBackTraceFrame
    lastFrame*: PBackTraceFrame

  IM3BacktraceInfo* = ptr M3BacktraceInfo

  PWasmVal* = ptr WasmVal
  ImportInfo* {.bycopy.} = object
    moduleUtf8*: cstring
    fieldUtf8*: cstring

  PM3ImportInfo* = ptr ImportInfo
  ImportContext* {.importc:"M3ImportContext", bycopy.} = object
    userdata*: pointer
    function*: PFunction

  PImportContext* = ptr ImportContext
  WasmProc* = proc (runtime: PRuntime; ctx: PImportContext; sp: ptr uint64; mem: pointer): pointer {.cdecl.}
  M3SectionHandler* = proc (i_module: PModule; name: cstring; start: ptr uint8; `end`: ptr uint8): Result {.cdecl.}

const
  none* {.importc: "m3Err_none".} : Result = ""
  mallocFailed* {.importc: "m3Err_mallocFailed".} : Result = ""
  incompatibleWasmVersion* {.importc: "m3Err_incompatibleWasmVersion".} : Result = ""
  wasmMalformed* {.importc: "m3Err_wasmMalformed".} : Result = ""
  misorderedWasmSection* {.importc: "m3Err_misorderedWasmSection".} : Result = ""
  wasmUnderrun* {.importc: "m3Err_wasmUnderrun".} : Result = ""
  wasmOverrun* {.importc: "m3Err_wasmOverrun".} : Result = ""
  wasmMissingInitExpr* {.importc: "m3Err_wasmMissingInitExpr".} : Result = ""
  lebOverflow* {.importc: "m3Err_lebOverflow".} : Result = ""
  missingUTF8* {.importc: "m3Err_missingUTF8".}: Result = ""
  wasmSectionUnderrun* {.importc: "m3Err_wasmSectionUnderrun".}: Result = ""
  wasmSectionOverrun* {.importc: "m3Err_wasmSectionOverrun".}: Result = ""
  invalidTypeId* {.importc: "m3Err_invalidTypeId".}: Result = ""
  tooManyMemory* {.importc: "m3Err_tooManyMemorySections".}: Result = ""
  tooManyArgs* {.importc: "m3Err_tooManyArgsRets".}: Result = ""
  moduleNotLinked* {.importc: "m3Err_moduleNotLinked".}: Result = ""
  moduleAlreadyLinked* {.importc: "m3Err_moduleAlreadyLinked".}: Result = ""
  functionLookupFailed* {.importc: "m3Err_functionLookupFailed".}: Result = ""
  functionImportMissing* {.importc: "m3Err_functionImportMissing".}: Result = ""
  malformedFunctionSignature* {.importc: "m3Err_malformedFunctionSignature".}: Result = ""
  noCompiler* {.importc: "m3Err_noCompiler".}: Result = ""
  unknownOpcode* {.importc: "m3Err_unknownOpcode".}: Result = ""
  restrictedOpcode*{.importc: "m3Err_restrictedOpcode".}: Result = ""
  functionStackOverflow* {.importc: "m3Err_functionStackOverflow".}: Result = ""
  functionStackUnderrun* {.importc: "m3Err_functionStackUnderrun".}: Result = ""
  mallocFailedCode* {.importc: "m3Err_mallocFailedCodePage".}: Result = ""
  settingImmutableGlobal* {.importc: "m3Err_settingImmutableGlobal".}: Result = ""
  typeMismatch*{.importc: "m3Err_typeMismatch".}: Result = ""
  typeCountMismatch* {.importc: "m3Err_typeCountMismatch".}: Result = ""
  missingCompiledCode* {.importc: "m3Err_missingCompiledCode".}: Result = ""
  wasmMemoryOverflow* {.importc: "m3Err_wasmMemoryOverflow".}: Result = ""
  globalMemoryNot* {.importc: "m3Err_globalMemoryNotAllocated".}: Result = ""
  globaIndexOut* {.importc: "m3Err_globaIndexOutOfBounds".}: Result = ""
  argumentCountMismatch* {.importc: "m3Err_argumentCountMismatch".}: Result = ""
  argumentTypeMismatch* {.importc: "m3Err_argumentTypeMismatch".}: Result = ""
  globalLookupFailed* {.importc: "m3Err_globalLookupFailed".}: Result = ""
  globalTypeMismatch* {.importc: "m3Err_globalTypeMismatch".}: Result = ""
  globalNotMutable* {.importc: "m3Err_globalNotMutable".}: Result = ""
  trapOutOf* {.importc: "m3Err_trapOutOfBoundsMemoryAccess".}: Result = ""
  trapDivisionBy* {.importc: "m3Err_trapDivisionByZero".}: Result = ""
  trapIntegerOverflow* {.importc: "m3Err_trapIntegerOverflow".}: Result = ""
  trapIntegerConversion* {.importc: "m3Err_trapIntegerConversion".}: Result = ""
  trapIndirectCall* {.importc: "m3Err_trapIndirectCallTypeMismatch".}: Result = ""
  trapTableIndex* {.importc: "m3Err_trapTableIndexOutOfRange".}: Result = ""
  trapTableElement* {.importc: "m3Err_trapTableElementIsNull".}: Result = ""
  trapExit*{.importc: "m3Err_trapExit".}: Result = ""
  trapAbort*{.importc: "m3Err_trapAbort".}: Result = ""
  trapUnreachable*{.importc: "m3Err_trapUnreachable".}: Result = ""
  trapStackOverflow* {.importc: "m3Err_trapStackOverflow".}: Result = ""

{.push importc.}

proc m3_NewEnvironment*(): PEnv
proc m3_FreeEnvironment*(i_environment: PEnv)


proc m3_SetCustomSectionHandler*(i_environment: PEnv;
                                i_handler: M3SectionHandler)
proc m3_NewRuntime*(io_environment: PEnv; i_stackSizeInBytes: uint32;
                   i_userdata: pointer): PRuntime
proc m3_FreeRuntime*(i_runtime: PRuntime)
proc m3_GetMemory*(i_runtime: PRuntime; o_memorySizeInBytes: ptr uint32;
                  i_memoryIndex: uint32): ptr uint8
proc m3_GetMemorySize*(i_runtime: PRuntime): uint32
proc m3_GetUserData*(i_runtime: PRuntime): pointer
proc m3_ParseModule*(i_environment: PEnv; o_module: ptr PModule;
                    i_wasmBytes: ptr uint8; i_numWasmBytes: uint32): Result
proc m3_FreeModule*(i_module: PModule)
proc m3_LoadModule*(io_runtime: PRuntime; io_module: PModule): Result
proc m3_CompileModule*(io_module: PModule): Result
proc m3_RunStart*(i_module: PModule): Result


proc m3_LinkRawFunction*(io_module: PModule; i_moduleName: cstring;
                        i_functionName: cstring; i_signature: cstring;
                        i_function: WasmProc): Result
proc m3_LinkRawFunctionEx*(io_module: PModule; i_moduleName: cstring;
                          i_functionName: cstring; i_signature: cstring;
                          i_function: WasmProc; i_userdata: pointer): Result
proc m3_GetModuleName*(i_module: PModule): cstring
proc m3_SetModuleName*(i_module: PModule; name: cstring)
proc m3_GetModuleRuntime*(i_module: PModule): PRuntime
proc m3_FindGlobal*(io_module: PModule; i_globalName: cstring): PGlobal
proc m3_GetGlobal*(i_global: PGlobal; o_value: PWasmVal): Result
proc m3_SetGlobal*(i_global: PGlobal; i_value: PWasmVal): Result
proc m3_GetGlobalType*(i_global: PGlobal): ValueKind
proc m3_Yield*(): Result
proc m3_FindFunction*(o_function: ptr PFunction; i_runtime: PRuntime;
                     i_functionName: cstring): Result
proc m3_GetArgCount*(i_function: PFunction): uint32
proc m3_GetRetCount*(i_function: PFunction): uint32
proc m3_GetArgType*(i_function: PFunction; i_index: uint32): ValueKind
proc m3_GetRetType*(i_function: PFunction; i_index: uint32): ValueKind
proc m3_CallV*(i_function: PFunction): Result {.varargs.}
#proc m3_CallVL*(i_function: PFunction; i_args: va_list): Result
proc m3_Call*(i_function: PFunction; i_argc: uint32; i_argptrs: ptr pointer): Result
proc m3_CallArgv*(i_function: PFunction; i_argc: uint32; i_argv: ptr cstring): Result
proc m3_GetResultsV*(i_function: PFunction): Result {.varargs.}
#proc m3_GetResultsVL*(i_function: PFunction; o_rets: va_list): Result
proc m3_GetResults*(i_function: PFunction; i_retc: uint32; o_retptrs: ptr pointer): Result
proc m3_GetErrorInfo*(i_runtime: PRuntime; o_info: ptr ErrorInfo)
proc m3_ResetErrorInfo*(i_runtime: PRuntime)
proc m3_GetFunctionName*(i_function: PFunction): cstring
proc m3_GetFunctionModule*(i_function: PFunction): PModule
proc m3_PrintRuntimeInfo*(i_runtime: PRuntime)
proc m3_PrintM3Info*()
proc m3_PrintProfilerInfo*()
proc m3_GetBacktrace*(i_runtime: PRuntime): IM3BacktraceInfo
{.pop.}
{.pop.}


when defined(wasm3HasWasi):
  proc m3_LinkWASI*(module: PModule): Result {.importc: "m3_LinkWASI", header: "m3_api_wasi.h".}
