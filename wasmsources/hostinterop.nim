import wasm3/exporter

proc myAlloc*(size: uint32): pointer {.wasmexport.} = system.alloc(int(size))
proc myDealloc*(p: pointer) {.wasmexport.} = system.dealloc(p)

type
  HeapArray[T] {.packed.} = object # Packed is important for interop
    len: uint32
    data: ptr UncheckedArray[T]
  MyType {.packed.} = object
    x: int32
    y: bool
    z: cstring


proc arrCheck1(intArray: HeapArray[int32]): bool {.wasmExport.} =
  intArray.data.toOpenArray(0, int intArray.len - 1) == [10i32, 20, 30, 40]

proc arrCheck2(myArray: HeapArray[MyType]): bool {.wasmExport.} =
  const myArr = [
    MyType(x: 100, y: true, z: "hello world"),
    MyType(x: 42, y: false, z: "Bleh"),
    MyType(x: 314159265i32, y: false, z: "Meh")
  ]
  myArray.data.toOpenArray(0, int(myArray.len - 1)) == myArr


proc returnCstringArray*(len: var int): cstringarray {.wasmexport.} =
  var arr {.global.} = [cstring"hello", "world", ""] # to do this properly use alloc
  len = arr.len
  cast[cstringarray](arr.addr)


proc returnSizedCstringArray*(len: var int): ptr UncheckedArray[(cstring, int)] {.wasmexport.} =
  var arr {.global.} = [(cstring"hello", 5), ("world", 5), ("", 0)] # to do this properly use alloc
  len = arr.len
  cast[ptr UncheckedArray[(cstring, int)]](arr.addr)
