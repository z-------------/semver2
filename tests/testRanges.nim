import std/unittest

import semver2

suite "ranges":
  test "comparator example from node-semver readme":
    const Range = ">=1.2.7"
    for s in ["1.2.7", "1.2.8", "2.5.3", "1.3.9"]:
      check initSemVer(s).satisfies(Range)
    for s in ["1.2.6", "1.1.0"]:
      check not initSemVer(s).satisfies(Range)

  test "comparator set example from node-semver readme":
    const Range = ">=1.2.7 <1.3.0"
    for s in ["1.2.7", "1.2.8", "1.2.99"]:
      check initSemVer(s).satisfies(Range)
    for s in ["1.2.6", "1.3.0", "1.1.0"]:
      check not initSemVer(s).satisfies(Range)

  test "range example from node-semver readme":
    const Range = "1.2.7 || >=1.2.9 <2.0.0"
    for s in ["1.2.7", "1.2.9", "1.4.6"]:
      check initSemVer(s).satisfies(Range)
    for s in ["1.2.8", "2.0.0"]:
      check not initSemVer(s).satisfies(Range)
