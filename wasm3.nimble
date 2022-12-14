# Package

version       = "0.1.0"
author        = "jason"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.6.6"
requires "https://github.com/beef331/micros/"


import std/[strutils, os]

task buildWasmSources, "Builds all wasmsources and moves them to 'tests'":
  for file in "wasmsources".listFiles:
    if file.endsWith".nim":
      selfExec("c " & file)
