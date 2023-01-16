# wasm3
Nim bindings of the lovely [wasm3](https://github.com/wasm3/wasm3) Wasm runtime.

## How to use?

add this to your project's .nimble file:

```nim
requires "https://github.com/beef331/wasm3 >= 0.1.1"
```

then run `nimble install -d`

Then a basic program with can be written as follows:
```nim
import unittest
import wasm3
let
  env = loadWasmEnv(readFile"maths.wasm")
  addFunc = env.findFunction("add")
  multiplyFunc = env.findFunction("multiply")
check addFunc.call(int32, 3i32, 4i32) == 7i32
check multiplyFunc.call(int32, 3i32, 4i32) == 12i32
```

If your Wasm file or application requires Wasi you can compile with `-d:wasm3HasWasi` and then use any of the Wasi procedures.

These bindings have some high level wrappings done inside `wasm3`
If one wants low level control one can always `import wasm3/wasm3c` and use the bindings directly.

### How to compile Nim code to work with the runtime?

#### Emscripten
Install [emscripten](https://github.com/emscripten-core/emsdk#downloads--how-do-i-get-the-latest-emscripten-build) then use this [config](https://github.com/beef331/wasm3/blob/master/wasmsources/config.nims). 
For emscripten you can use `wasm3/exporter` utillities to export code to the runtime.

#### Nlvm
You can follow the instructions [here](https://github.com/arnetheduck/nlvm#wasm32-support) though the Nlvm stdlib does not support WASI at the time of writing.


#### example wasm

Here is an example rust wasm you can use in above example-code:

```rs
// rustc --target wasm32-unknown-unknown maths.rs -o maths.wasm --crate-type cdylib

#[no_mangle]
pub extern fn add(x: i32, y: i32) -> i32 {
    x + y
}

#[no_mangle]
pub extern fn multiply(x: i32, y: i32) -> i32 {
    x * y
}
```

## How Wasm3 is compiled?
Wasm3 is a git submodule and compiled directly using Nim's `{.compile.}`.
There are no dynamic or static libraries as it is included directly as C source code.
Wasm3 is licensed under the MIT license as are these bindings.
