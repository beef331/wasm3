import wasm3c
## TODO: Implement this

type
  WasmTypes* = int32 or uint32 or int64 or uint64 or float32 or float64
  WasmType* = concept wt, type WT
    var
      alloc: PFunction
      free: PFunction
      stackPointer: ptr uint64
    wt.toWasm(alloc, free) is pointer
    wasmType(WT) is WasmTypes
    fromWasm(stackPointer, wt) is void


