import std/[macros]
{.emit: """/*INCLUDESECTION*/
#include <emscripten.h>
""".}

macro wasmexport*(t: typed): untyped =
  if t.kind notin {nnkProcDef, nnkFuncDef}:
    error("Can only export procedures", t)
  let
    newProc = copyNimTree(t)
    codeGen = nnkExprColonExpr.newTree(ident"codegendecl", newLit"EMSCRIPTEN_KEEPALIVE $# $#$#")
  if newProc[4].kind == nnkEmpty:
    newProc[4] = nnkPragma.newTree(codeGen)
  else:
    newProc[4].add codeGen
  newProc[4].add ident"exportC"
  result = newStmtList(newProc)

template exportVar*(name: untyped, typ: typedesc) =
  var name {.exportC, codegendecl:"$# EMSCRIPTEN_KEEPALIVE $#".}: typ
