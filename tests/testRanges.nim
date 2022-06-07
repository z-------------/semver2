import std/unittest

import semver2

suite "ranges":
  test "comparator example from node-semver readme":
    const Range = initRange(">=1.2.7")
    for s in ["1.2.7", "1.2.8", "2.5.3", "1.3.9"]:
      check initSemver(s) in Range
    for s in ["1.2.6", "1.1.0"]:
      check initSemver(s) notin Range

  test "comparator set example from node-semver readme":
    const Range = initRange(">=1.2.7 <1.3.0")
    for s in ["1.2.7", "1.2.8", "1.2.99"]:
      check initSemver(s) in Range
    for s in ["1.2.6", "1.3.0", "1.1.0"]:
      check initSemver(s) notin Range

  test "primitive range example from node-semver readme":
    const Range = initRange("1.2.7 || >=1.2.9 <2.0.0")
    for s in ["1.2.7", "1.2.9", "1.4.6"]:
      check initSemver(s) in Range
    for s in ["1.2.8", "2.0.0"]:
      check initSemver(s) notin Range

  test "hyphen range examples from node-semver readme":
    for (ramge, expected) in [
      ("1.2.3 - 2.3.4", ">=1.2.3 <=2.3.4"),
      ("1.2 - 2.3.4", ">=1.2.0 <=2.3.4"),
      ("1.2.3 - 2.3", ">=1.2.3 <2.4.0-0"),
      ("1.2.3 - 2", ">=1.2.3 <3.0.0-0"),
    ]:
      check initRange(ramge) == initRange(expected)

  test "x-range examples from node-semver readme":
    for (ramge, expected) in [
      ("*", ">=0.0.0"),
      ("1.x", ">=1.0.0 <2.0.0-0"),
      ("1.2.x", ">=1.2.0 <1.3.0-0"),
      ("", ">=0.0.0"),
      ("1", ">=1.0.0 <2.0.0-0"),
      ("1.2", ">=1.2.0 <1.3.0-0"),
    ]:
      check initRange(ramge) == initRange(expected)

  test "tilde range examples from node-semver readme":
    for (ramge, expected) in [
      ("~1.2.3", ">=1.2.3 <1.3.0-0"),
      ("~1.2", ">=1.2.0 <1.3.0-0"),
      ("~1", ">=1.0.0 <2.0.0-0"),
      ("~0.2.3", ">=0.2.3 <0.3.0-0"),
      ("~0.2", ">=0.2.0 <0.3.0-0"),
      ("~0", ">=0.0.0 <1.0.0-0"),
      ("~1.2.3-beta.2", ">=1.2.3-beta.2 <1.3.0-0"),
    ]:
      check initRange(ramge) == initRange(expected)

  test "caret range examples from node-semver readme":
    for (ramge, expected) in [
      ("^1.2.3", ">=1.2.3 <2.0.0-0"),
      ("^0.2.3", ">=0.2.3 <0.3.0-0"),
      ("^0.0.3", ">=0.0.3 <0.0.4-0"),
      ("^1.2.3-beta.2", ">=1.2.3-beta.2 <2.0.0-0"),
      ("^0.0.3-beta", ">=0.0.3-beta <0.0.4-0"),
      ("^1.2.x", ">=1.2.0 <2.0.0-0"),
      ("^0.0.x", ">=0.0.0 <0.1.0-0"),
      ("^0.0", ">=0.0.0 <0.1.0-0"),
      ("^1.x", ">=1.0.0 <2.0.0-0"),
      ("^0.x", ">=0.0.0 <1.0.0-0"),
    ]:
      check initRange(ramge) == initRange(expected)

  test "version with prerelease satisfies comparator set only if a comparator with the same core version also has prerelease":
    block primitive:
      let ramge = initRange(">1.2.3-alpha.3")
      check initSemver("1.2.3-alpha.7").satisfies(ramge)
      check not initSemver("3.4.5-alpha.9").satisfies(ramge)
      check initSemver("3.4.5").satisfies(ramge)

    block tilde:
      let ramge = initRange("~1.2.3-beta.2")
      check not initSemver("1.2.3-beta.1").satisfies(ramge)
      check initSemver("1.2.3-beta.4").satisfies(ramge)
      check not initSemver("1.2.4-beta.2").satisfies(ramge)

    block caret:
      let ramge = initRange("^1.2.3-beta.2")
      check not initSemver("1.2.3-beta.1").satisfies(ramge)
      check initSemver("1.2.3-beta.4").satisfies(ramge)
      check not initSemver("1.2.4-beta.2").satisfies(ramge)

    block caret:
      let ramge = initRange("^0.0.3-beta")
      check not initSemver("0.0.3-alpha").satisfies(ramge)
      check initSemver("0.0.3-pr.2").satisfies(ramge)
      check not initSemver("0.0.4-pr.2").satisfies(ramge)

  test "raise value error for invalid ranges":
    const InvalidRangeStrs = [
      # non-final X
      "x.2.3",
      "1.x.3",
    ]
    for version in InvalidRangeStrs:
      expect ValueError:
        discard initSemver(version)
