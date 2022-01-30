# Package

version       = "0.0.1"
author        = "Zack Guard"
description   = "SemVer parsing, comparison, and ranges"
license       = "GPL-3.0-or-later"
srcDir        = "src"

# Dependencies

requires "nim >= 1.6.0"
requires "npeg >= 0.26.0"

# Tasks

task tag, "Create a git annotated tag with the current nimble version":
  let tagName = "v" & version
  exec "git tag -a " & tagName & " -m " & tagName
