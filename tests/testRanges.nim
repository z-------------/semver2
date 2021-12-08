import std/unittest

import semver2
import ../src/semver2/ranges {.all.}

suite "ranges":
  test "comparator example from node-semver readme":
    const Range = parseRange(">=1.2.7")
    for s in ["1.2.7", "1.2.8", "2.5.3", "1.3.9"]:
      check initSemVer(s) in Range
    for s in ["1.2.6", "1.1.0"]:
      check initSemVer(s) notin Range

  test "comparator set example from node-semver readme":
    const Range = parseRange(">=1.2.7 <1.3.0")
    for s in ["1.2.7", "1.2.8", "1.2.99"]:
      check initSemVer(s) in Range
    for s in ["1.2.6", "1.3.0", "1.1.0"]:
      check initSemVer(s) notin Range

  test "range example from node-semver readme":
    const Range = parseRange("1.2.7 || >=1.2.9 <2.0.0")
    for s in ["1.2.7", "1.2.9", "1.4.6"]:
      check initSemVer(s) in Range
    for s in ["1.2.8", "2.0.0"]:
      check initSemVer(s) notin Range

  test "hyphen range examples from node-semver readme":
    for (ramge, expected) in [
      ("1.2.3 - 2.3.4", ">=1.2.3 <=2.3.4"),
      ("1.2 - 2.3.4", ">=1.2.0 <=2.3.4"),
      ("1.2.3 - 2.3", ">=1.2.3 <2.4.0-0"),
      ("1.2.3 - 2", ">=1.2.3 <3.0.0-0"),
    ]:
      check parseRange(ramge) == parseRange(expected)
